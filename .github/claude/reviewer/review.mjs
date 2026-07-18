// Agentic PR reviewer with cross-push de-duplication and auto-resolution.
//
// Flow: run a read-only Claude agent that emits structured JSON findings ->
// reconcile against prior runs via a hidden fingerprint marker on each comment ->
// post only NEW findings, keep matching ones, and RESOLVE stale ones (GraphQL).
// Ported from Karta/core-i2c/CICD/PR_REVIEW/review.mjs (Bitbucket) to GitHub.

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { query } from '@anthropic-ai/claude-agent-sdk';
import {
  listIssueComments,
  postIssueComment,
  updateIssueComment,
  postInlineComment,
  listReviewThreads,
  resolveReviewThread,
} from './github.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

const MARKER_SUMMARY = '<!-- bp-ai-review-summary -->';
const FP_REGEX = /<!-- bp-ai-review-fp:([a-f0-9]+) -->/;

const MODEL = process.env.REVIEW_MODEL || 'claude-opus-4-8';
const MAX_TURNS = Number(process.env.REVIEW_MAX_TURNS || 40);
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';
const RUN_URL = process.env.RUN_URL || '';

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

const PR_NUMBER = Number(requireEnv('PR_NUMBER'));
const COMMIT = requireEnv('COMMIT'); // PR head SHA — anchors inline comments
const BASE = process.env.BASE_REF || 'develop';

// Fingerprint identifies "the same issue at the same spot" across runs.
// Intentionally EXCLUDES the comment text so a re-wording doesn't create a duplicate.
function fingerprint(f) {
  return createHash('sha1').update(`${f.file}|${f.line}|${f.severity}`).digest('hex').slice(0, 12);
}

function severityEmoji(s) {
  return s === 'error' ? '🔴' : s === 'warn' ? '🟡' : '🔵';
}

const OUTPUT_CONTRACT = `
## Output contract (READ-ONLY — the harness posts, you do not)

You have read-only tools (Read, Grep, Glob, and Bash limited to git/gh/cat/ls). Do NOT post comments,
create reviews, push, or modify anything — an automated harness posts your findings, de-duplicates them
against previous runs, and resolves stale ones. Your job is only to investigate and report.

After investigating, your FINAL assistant message MUST end with a single fenced \`\`\`json block of
exactly this shape, with NOTHING after it:

\`\`\`json
{
  "verdict": "pass" | "warn" | "fail",
  "summary": "2-6 sentence Markdown summary of the PR scope and key risks.",
  "findings": [
    { "severity": "info" | "warn" | "error", "file": "BookPlayer/Player/PlayerViewModel.swift", "line": 42, "comment": "Markdown explanation + concrete fix." }
  ]
}
\`\`\`

- \`line\` is the line number in the NEW version of the file, and MUST be a line changed by this PR
  (so it can be attached as an inline comment). If a finding can't be tied to a changed line, fold it
  into the summary instead of inventing a line.
- \`verdict: "fail"\` requires at least one \`error\` finding.
- Keep findings to issues you are confident in. False positives erode trust — when unsure, downgrade
  the severity or drop it. No prose after the JSON block.
`;

const SYSTEM_PROMPT =
  readFileSync(join(__dirname, '..', 'review-guide.md'), 'utf8') + '\n' + OUTPUT_CONTRACT;

const USER_PROMPT = `You are reviewing pull request #${PR_NUMBER} (base branch \`${BASE}\`) of BookPlayer for iOS.

Steps:
1. Run \`gh pr diff ${PR_NUMBER}\` to see the changes.
2. Read \`CLAUDE.md\` and apply the rubric from your system prompt.
3. For each non-trivial change, open the surrounding code and its callers (Read/Grep/Glob) before
   judging — do not review the diff in isolation. Check memory/concurrency (retain cycles, [weak self]
   in closures/Combine sinks, stored cancellables, @MainActor / thread-correct DB access), player and
   AVAudioSession lifecycle, and the BookPlayerKit boundary where relevant.
4. Emit the final JSON block per the output contract. Do not post anything yourself.

The repository is checked out in the current working directory. Do not modify files.`;

function extractJson(text) {
  const fence = text.match(/```(?:json)?\s*\n([\s\S]*?)\n```\s*$/m);
  const candidate = fence ? fence[1] : text;
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('No JSON object found in agent output');
  return JSON.parse(candidate.slice(start, end + 1));
}

async function runAgent() {
  let finalText = '';
  let turns = 0;
  let resultSubtype = null;
  const stderrChunks = [];
  const iterator = query({
    prompt: USER_PROMPT,
    options: {
      model: MODEL,
      systemPrompt: SYSTEM_PROMPT,
      allowedTools: ['Read', 'Grep', 'Glob', 'Bash'],
      permissionMode: 'bypassPermissions',
      maxTurns: MAX_TURNS,
      cwd: process.env.GITHUB_WORKSPACE || process.cwd(),
      stderr: (d) => {
        stderrChunks.push(d);
        process.stderr.write(`[claude] ${d}`);
      },
    },
  });
  try {
    for await (const msg of iterator) {
      if (msg.type === 'assistant') {
        turns++;
        const content = msg.message?.content;
        if (Array.isArray(content)) {
          for (const block of content) {
            if (block.type === 'text' && block.text) finalText = block.text;
            if (block.type === 'tool_use') {
              // Log the tool name only — not its input, which can contain file paths / queries.
              console.log(`  [turn ${turns}] ${block.name}`);
            }
          }
        }
      } else if (msg.type === 'result') {
        resultSubtype = msg.subtype || null;
        if (resultSubtype && resultSubtype !== 'success') {
          console.warn(`Agent terminated: ${resultSubtype}`);
        }
      }
    }
  } catch (err) {
    err.capturedStderr = stderrChunks.join('');
    throw err;
  }
  return { finalText, turns, resultSubtype };
}

function renderSummary(result, stats, unpostable) {
  const emoji = result.verdict === 'fail' ? '🔴' : result.verdict === 'warn' ? '🟡' : '✅';
  const counts = result.findings.reduce(
    (a, f) => ({ ...a, [f.severity]: (a[f.severity] || 0) + 1 }),
    {},
  );
  const countLine =
    ['error', 'warn', 'info'].filter((s) => counts[s]).map((s) => `${counts[s]} ${s}`).join(' · ') ||
    'no findings';

  const lines = [
    `## ${emoji} Claude PR Review — \`${result.verdict.toUpperCase()}\``,
    '',
    result.summary,
    '',
    `**Findings:** ${countLine}`,
  ];

  if (unpostable.length) {
    lines.push(
      '',
      '<details><summary>Findings not attached inline (line not in this diff)</summary>',
      '',
      ...unpostable.map((f) => `- ${severityEmoji(f.severity)} \`${f.file}:${f.line}\` — ${f.comment}`),
      '',
      '</details>',
    );
  }

  lines.push(
    '',
    `<sub>Model \`${MODEL}\`${RUN_URL ? ` · [run log](${RUN_URL})` : ''} · ${stats.posted} new · ${stats.kept} carried over · ${stats.resolved} resolved · advisory (a human should still review). Duplicate findings are de-duplicated and stale ones auto-resolved across pushes.</sub>`,
    '',
    MARKER_SUMMARY,
  );
  return lines.join('\n');
}

async function upsertSummary(body) {
  const existing = (await listIssueComments(PR_NUMBER)).find((c) =>
    (c.body || '').includes(MARKER_SUMMARY),
  );
  if (existing) return updateIssueComment(existing.id, body);
  return postIssueComment(PR_NUMBER, body);
}

async function main() {
  requireEnv('ANTHROPIC_API_KEY');
  requireEnv('GITHUB_TOKEN');
  console.log(`Reviewing PR #${PR_NUMBER} (base ${BASE}, head ${COMMIT.slice(0, 8)}) with ${MODEL}`);

  const { finalText, turns, resultSubtype } = await runAgent();
  console.log(`Agent finished in ${turns} turns (${resultSubtype || 'no-result'})`);

  // Parse the agent's JSON. If it truncated (e.g. hit the turn limit on a large PR) or
  // produced malformed output, degrade gracefully: post a visible note and exit 0 rather
  // than hard-failing the check with nothing.
  let parsed;
  try {
    if (!finalText) throw new Error('agent produced no text output');
    parsed = extractJson(finalText);
    if (!parsed.verdict || !parsed.summary || !Array.isArray(parsed.findings)) {
      throw new Error('JSON missing verdict/summary/findings');
    }
  } catch (e) {
    const reason =
      resultSubtype === 'error_max_turns'
        ? 'hit the turn limit before finishing — likely a large PR. Bump `REVIEW_MAX_TURNS` or split the PR into smaller ones.'
        : `could not produce a structured result (${e.message}).`;
    console.warn(`Review incomplete: ${reason}`);
    if (!DRY_RUN) {
      await upsertSummary(
        ['## ⚠️ Claude PR Review — incomplete', '', `The reviewer ${reason}`, '', MARKER_SUMMARY].join('\n'),
      ).catch((err) => console.warn(`Could not post incomplete-review note: ${err.message}`));
    }
    return;
  }

  // Current findings, de-duplicated by fingerprint.
  const VALID_SEVERITY = new Set(['info', 'warn', 'error']);
  const currentByFp = new Map();
  let dropped = 0;
  for (const f of parsed.findings) {
    if (!f.file || !f.line || !f.comment || !VALID_SEVERITY.has(f.severity)) {
      dropped++;
      continue;
    }
    currentByFp.set(fingerprint(f), f);
  }
  if (dropped) console.warn(`Dropped ${dropped} malformed finding(s) (missing field or invalid severity)`);

  if (DRY_RUN) {
    console.log('\n===== DRY RUN =====');
    for (const [fp, f] of currentByFp) {
      console.log(`${severityEmoji(f.severity)} ${f.file}:${f.line} [${fp}] ${f.comment}`);
    }
    console.log('\n--- summary ---');
    console.log(renderSummary(parsed, { posted: 0, kept: 0, resolved: 0 }, []));
    return;
  }

  // Prior threads we created (identified by the fp marker on their first comment).
  const threads = await listReviewThreads(PR_NUMBER).catch((e) => {
    console.warn(`listReviewThreads failed: ${e.message}`);
    return [];
  });
  const existingByFp = new Map();
  for (const t of threads) {
    const m = t.firstCommentBody.match(FP_REGEX);
    if (m) existingByFp.set(m[1], t);
  }

  // Post NEW findings; carry over ones already present; collect unpostable (line not in diff).
  const stats = { posted: 0, kept: 0, resolved: 0 };
  const unpostable = [];
  for (const [fp, f] of currentByFp) {
    if (existingByFp.has(fp)) {
      stats.kept++;
      continue;
    }
    const body = `${severityEmoji(f.severity)} **${f.severity.toUpperCase()}** — ${f.comment}\n\n<!-- bp-ai-review-fp:${fp} -->`;
    try {
      await postInlineComment({ prNumber: PR_NUMBER, commitId: COMMIT, path: f.file, line: f.line, body });
      stats.posted++;
    } catch (e) {
      console.warn(`inline post failed ${f.file}:${f.line} — ${e.message}`);
      unpostable.push(f);
    }
  }

  // Resolve stale, still-open threads whose finding is gone from the current run.
  for (const [fp, t] of existingByFp) {
    if (currentByFp.has(fp) || t.isResolved) continue;
    try {
      await resolveReviewThread(t.id);
      stats.resolved++;
    } catch (e) {
      console.warn(`resolve failed (fp:${fp}) — ${e.message}`);
    }
  }

  await upsertSummary(renderSummary(parsed, stats, unpostable));
  console.log(
    `Reconcile: ${stats.posted} new, ${stats.kept} kept, ${stats.resolved} resolved, ${unpostable.length} unpostable`,
  );
  console.log(`Done. Verdict: ${parsed.verdict}`);
  // Advisory by design: exit 0 regardless of verdict so the review never blocks a merge.
  // To make it a hard gate (failed check that blocks merge on a "fail" verdict),
  // exit 1 here when parsed.verdict === 'fail'.
}

main().catch((err) => {
  console.error('Fatal:', err);
  if (err.capturedStderr) {
    console.error('--- claude stderr ---');
    console.error(err.capturedStderr);
  }
  process.exit(1);
});
