// The model seam: the SDK options that ARE the sandbox in practice, the run loop with its deadline and salvage,
// model resolution, and the parsers that read a result out of whatever the agent's final message turned out to
// be. Everything the tests stub lives behind `runAgent`.

import { randomBytes } from 'node:crypto';
import { num } from './config.mjs';
import { agentCwd, agentEnv, boundedDump, canUseTool, redact } from './sandbox.mjs';
import { buildSystemPrompt } from './prompts.mjs';

// Model is resolved at runtime (newest Opus-tier id from the Models API) unless REVIEW_MODEL pins one.
// Used only when the Models API cannot be reached. An ordered list, not one constant: a single retired id would
// otherwise leave the retry with nowhere to go (retryModel === MODEL trips its own guard) and the reviewer offline
// until someone edited this file.
export const FALLBACK_MODELS = ['claude-opus-5-5', 'claude-opus-5', 'claude-opus-4-8', 'claude-opus-4-7', 'claude-opus-4-6'];

export const FALLBACK_MODEL = FALLBACK_MODELS[0];

export let MODEL = process.env.REVIEW_MODEL || '';
// The one piece of runtime state another module changes: `runReview` resolves the model and, on a failed run,
// switches to the runner-up. An imported `let` is read-only where it is imported, so the change comes through here.
export function setModel(name) {
  MODEL = name;
}

export let RANKED_MODELS = []; // from the Models API, newest first; the retry prefers the runner-up to the constant

const maxTurns = () => num(process.env.REVIEW_MAX_TURNS, 40);

// The agent's answer is one JSON object holding every finding, so it is far longer than a chat reply and the
// default output cap cut it off mid-object on two real runs: the summary named two problems and only the first
// finding survived the truncation repair. The SDK reads this from the subprocess environment.
const maxOutputTokens = () => num(process.env.REVIEW_MAX_OUTPUT_TOKENS, 32_000);


// Opus-tier ids from a /v1/models listing, newest first: highest version, the undated rolling id before a
// dated snapshot of the same version (claude-opus-5 before claude-opus-5-20260601), then newest created_at.
export function rankOpusModels(models) {
  return (models || [])
    .map((m) => {
      const match = /^claude-opus-(\d{1,2})(?:-(\d{1,2}))?(?:-(\d{8}))?$/.exec(m.id || '');
      return match && {
        id: m.id,
        major: Number(match[1]),
        minor: Number(match[2] || 0),
        dated: Boolean(match[3]),
        created: new Date(m.created_at || 0),
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.major - a.major || b.minor - a.minor || a.dated - b.dated || b.created - a.created)
    .map((m) => m.id);
}

export async function resolveModel() {
  // The override is read here, per run, not from `MODEL` — which this module keeps across the scenarios a test
  // process runs, and which the model-unavailable retry has changed by the time a second run asks.
  if (process.env.REVIEW_MODEL) return process.env.REVIEW_MODEL;
  try {
    const res = await fetch('https://api.anthropic.com/v1/models?limit=100', {
      headers: { 'x-api-key': process.env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const { data } = await res.json();
    const ranked = rankOpusModels(data);
    if (!ranked.length) throw new Error(`no Opus-tier model among ${(data || []).length} listed`);
    console.log(`Opus candidates: ${ranked.slice(0, 4).join(', ')}`);
    RANKED_MODELS = ranked;
    return ranked[0];
  } catch (e) {
    console.warn(`Could not resolve the latest Opus model (${redact(e.message)}); using ${FALLBACK_MODEL}`);
    RANKED_MODELS = FALLBACK_MODELS; // so the model-unavailable retry has a runner-up to try
    return FALLBACK_MODEL;
  }
}

// Find the result object in the agent's final message. Candidates are each fenced block (last first), then the
// whole message. Within a candidate every `{` is tried outermost-first, walking to its balanced closing brace
// string-aware, and the first object with the result shape wins — so prose, decoy snippets and a finding that
// itself talks about `"verdict"` can't mislead it. If the message was cut off mid-object, closing it is attempted
// and accepted only when the repaired object validates.
export function extractJson(text) {
  const s = String(text);
  // The contract's own answer first: "your FINAL message MUST end with a single fenced ```json block … with
  // NOTHING after it". When the message really does end with a complete, result-shaped block, that block IS the
  // answer and nothing earlier in the message can outrank it. The scan below tries fenced blocks last-first and
  // takes the first COMPLETE result-shaped object it finds, which is right for repaired fragments and wrong here:
  // a finding's comment routinely embeds a fenced snippet, and this repo's own review guide and output contract
  // contain a `{ "verdict": …, "summary": …, "findings": [] }` example a reviewer may quote verbatim. Quoted back
  // as valid JSON, that decoy used to win. Truncated answers are unaffected: this parser returns null unless the
  // message ends with a balanced, parseable block.
  const terminal = parseTerminalFencedJson(s, (o) => isResultShape(o));
  if (terminal) return normaliseResult(terminal);
  const candidates = [...s.matchAll(/```[^\n]*\n?([\s\S]*?)```/g)].map((m) => m[1]).reverse();
  candidates.push(s);
  // A COMPLETE object anywhere beats a repaired one, and the whole message is always a candidate. Fence pairing is
  // unreliable by construction: the model is asked for concrete fixes, so a finding's comment routinely contains a
  // fenced snippet of its own, and the non-greedy fence regex then pairs the opening ```json with the snippet's
  // ```. The first fragment ends mid-object, the truncation repair closes it, and every finding after the snippet
  // is dropped — silently, and reported as the model's truncation. That is what was actually happening whenever a
  // review came back "cut off mid-JSON" with a complete summary; balancedEnd is string-aware, so the whole-message
  // candidate parses the real object correctly.
  let repaired = null;
  for (const candidate of candidates) {
    const found = findResultObject(candidate);
    if (!found) continue;
    if (!wasTruncationRepaired(found)) return normaliseResult(found);
    // Among repaired candidates, keep the richest rather than the first. Candidates run fenced-blocks-first and
    // the whole message is last, so "first wins" systematically preferred the fragment a mis-paired fence
    // produces — which holds only the findings written before the ```suggestion inside a comment. Verified: a
    // truncated 3-finding answer came back with 1.
    const better = (a, b) => (a?.findings?.length || 0) >= (b?.findings?.length || 0) ? a : b;
    repaired = repaired ? better(repaired, found) : found;
  }
  if (repaired) return markRepaired(normaliseResult(repaired));
  throw new Error('No parseable JSON object with verdict/summary/findings in agent output');
}

// The agent's final answer is whatever text it produced after its last tool call. A long answer can arrive as
// several text blocks, in one message or continued in the next when a response runs out of output room, and a
// split can fall mid-token — so blocks are concatenated with NO separator; the model's own newlines delimit its
// paragraphs. A tool call means the answer has not started yet, so the buffer is reset — and the text it held is
// returned as `discarded`, because "answer, then one more tool call" usually arrives in ONE message and the caller
// could not otherwise see what was dropped.
export function accumulateFinalText(current, content, onToolUse = () => {}) {
  let text = current;
  const discarded = []; // every segment a tool call reset, in order: one message can hold text→tool→text→tool
  for (const block of content) {
    if (block.type === 'tool_use') {
      if (text) discarded.push(text);
      text = '';
      onToolUse(block.name);
    } else if (block.type === 'text' && block.text) {
      text += block.text;
    }
  }
  return { text, discarded };
}

// Print an agent answer to the run log for diagnosis. The text is influenced by PR content and the runner interprets
// `::workflow-commands::` on any line, even indented ones, so the dump is bracketed by the runner's own escape hatch
// (`::stop-commands::<token>` … `::<token>::`, token unguessable) and, belt and braces, boundedDump breaks every
// leading `::`. Everything goes to stdout so the brackets and the dump keep their order (stdout and stderr are
// separate pipes to the runner).
export function logAgentOutput(label, text) {
  const token = randomBytes(16).toString('hex');
  console.log(`::group::${label} (${text.length} chars)`);
  console.log(`::stop-commands::${token}`);
  console.log(boundedDump(text));
  console.log(`::${token}::`);
  console.log('::endgroup::');
}

// Models sometimes put a real line break or tab inside a JSON string (a multi-paragraph summary), which JSON.parse
// rejects. Walk the text string-aware and escape control characters that occur inside string literals only:
// `\n` → `\\n`, `\t` → `\\t`, `\r` dropped (CRLF becomes LF), any other control character → a space.
export function escapeControlCharsInStrings(s) {
  let out = '';
  let inString = false;
  let escaped = false;
  for (const ch of s) {
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      } else if (ch === '\n') {
        out += '\\n';
        continue;
      } else if (ch === '\t') {
        out += '\\t';
        continue;
      } else if (ch === '\r') {
        continue;
      } else if (ch < ' ') {
        out += ' ';
        continue;
      }
    } else if (ch === '"') {
      inString = true;
    }
    out += ch;
  }
  return out;
}

const VERDICTS = new Set(['pass', 'warn', 'fail']);

// `findings` may be absent when the object closed on its own: a model with nothing to report tends to omit the key
// rather than send `[]`, and throwing the whole review away over that (seen live: a complete `pass` discarded as
// "incomplete") is the wrong trade. It may NOT be absent on a truncation-repaired object, where the missing key means
// the answer was cut off before the findings the agent had written — accepting that would post an empty result and
// auto-resolve every existing thread. Callers get it normalised to an array by `normaliseResult`.
function isResultShape(o, { allowMissingFindings = true } = {}) {
  if (!(Boolean(o) && typeof o === 'object' && VERDICTS.has(o.verdict) && isSummary(o.summary))) return false;
  if (Array.isArray(o.findings)) return true;
  // A `fail` asserting no findings contradicts the contract (a fail needs an error finding), so the shortcut is
  // limited to verdicts where "nothing to report" is coherent.
  return allowMissingFindings && o.verdict !== 'fail' && (o.findings === undefined || o.findings === null);
}

// The contract asks for a string, but a model writing a multi-paragraph summary sometimes emits an array of strings
// (seen live: a complete review discarded because `summary` was `["…", "…"]`). Both are accepted, one is stored.
function isSummary(v) {
  return typeof v === 'string' || (Array.isArray(v) && v.length > 0 && v.every((x) => typeof x === 'string'));
}

// The one place the post-extraction invariant is stated: whatever reaches reconcile() has a known verdict, a string
// summary and an array of findings. extractJson already guarantees it via normaliseResult; this makes that explicit
// for both the normal and the turn-limit-fallback path.
// Running out of time or turns is an expected outcome on a large PR: it must degrade to the visible "incomplete"
// note and exit 0, which is what the reasons in the parse block are written for. Only an unexpected subtype with no
// output at all is a real failure worth the red "did not run" check. (Before this, a deadline threw here and the
// error_deadline reason below was unreachable.)
export const DEGRADABLE_SUBTYPES = new Set(['error_max_turns', 'error_deadline']);

export function shouldHardFail({ finalText, lastAnswer, resultSubtype } = {}) {
  if (finalText) return false;
  if (lastAnswer && DEGRADABLE_SUBTYPES.has(resultSubtype)) return false; // the fallback below can still use it
  if (!resultSubtype || resultSubtype === 'success') return false;
  return !DEGRADABLE_SUBTYPES.has(resultSubtype);
}

export function assertResultShape(o) {
  if (!VERDICTS.has(o?.verdict) || typeof o.summary !== 'string' || !Array.isArray(o.findings)) {
    throw new Error('JSON missing or malformed verdict/summary/findings');
  }
  return o;
}

function normaliseResult(o) {
  if (Array.isArray(o.summary)) o.summary = o.summary.join('\n\n');
  if (!Array.isArray(o.findings)) o.findings = [];
  return o;
}

const TRUNCATION_CLOSERS = ['"}]}', '"}}]}', '}]}', ']}', '}'];

// A result the parser had to close itself is, by construction, a partial finding list: whatever the agent was still
// writing is missing. Marked on the object (invisibly, so it can never reach a comment) and read back in runReview(),
// which then declines to resolve anything on its authority.
const REPAIRED = Symbol('truncation-repaired');

const markRepaired = (o) => (o && typeof o === 'object' ? Object.defineProperty(o, REPAIRED, { value: true }) : o);

export const wasTruncationRepaired = (o) => Boolean(o && typeof o === 'object' && o[REPAIRED]);

function findResultObject(s) {
  for (let i = s.indexOf('{'); i !== -1; i = s.indexOf('{', i + 1)) {
    const end = balancedEnd(s, i);
    const complete = end !== -1; // closed on its own; anything else is a truncation repair
    // The control-character repair is applied to the object slice, so quote parity is judged from the object's own
    // `{`, not from prose before it (a stray `"` in a quoted snippet ahead of the object would otherwise invert it).
    // Computed once per candidate object — not once per truncation closer, which re-walked the slice five times.
    const body = complete ? s.slice(i, end + 1) : s.slice(i).trimEnd();
    const repaired = /[\x00-\x1f]/.test(body) ? escapeControlCharsInStrings(body) : null; // repair only when it can help
    const variants = repaired ? [body, repaired] : [body];
    const attempts = complete ? variants : TRUNCATION_CLOSERS.flatMap((c) => variants.map((v) => v + c));
    for (const attempt of attempts) {
      try {
        const parsed = JSON.parse(attempt);
        if (isResultShape(parsed, { allowMissingFindings: complete })) return complete ? parsed : markRepaired(parsed);
      } catch {
        // not this one
      }
    }
  }
  return null;
}

// Index of the brace closing the object that opens at `start`, or -1 if the text ends first.
function balancedEnd(s, start) {
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < s.length; i++) {
    const ch = s[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{') depth++;
    else if (ch === '}' && --depth === 0) return i;
  }
  return -1;
}

// True only when the text ends with the fenced result block the output contract mandates ("your FINAL message MUST
// end with a single fenced ```json block … with NOTHING after it"). A bare object, or a result-shaped snippet quoted
// in prose — reachable from PR content, e.g. this repo's own tests — does not count. Residual, accepted: an agent that
// echoes a complete ```json result block from the diff and then makes one more tool call before the turn limit is
// indistinguishable by shape. That case can only yield a review that is banner-marked provisional and resolves no
// threads, on a same-repo PR (fork PRs never reach the reviewer), so a human reads it as what it is.
export function parseTerminalFencedJson(text, accept = () => true) {
  const t = String(text).trimEnd();
  if (!t.endsWith('```')) return null;
  const closeIdx = t.length - 3;
  // Every line-start ```json fence, then tried newest first: the JSON routinely contains fenced code inside a
  // comment, so the fence nearest the end is not necessarily the one that opens the final block.
  const opens = [];
  // The tag may be `json` in any case, or absent: this is the verifier's primary parser as well as the review's
  // recovery gate, and we have twice seen the model deviate harmlessly from its own contract. What actually
  // guards against adopting a block quoted from the diff is the terminal position plus the shape check below.
  for (const m of t.slice(0, closeIdx).matchAll(/(?:^|\n)```[ \t]*(?:json)?[ \t]*\r?\n/gi)) opens.push(m.index + m[0].length);
  for (let k = opens.length - 1; k >= 0; k--) {
    const inner = t.slice(opens[k], closeIdx).trim();
    if (!inner.startsWith('{') || !inner.endsWith('}') || balancedEnd(inner, 0) !== inner.length - 1) continue;
    for (const attempt of [inner, escapeControlCharsInStrings(inner)]) {
      try {
        const o = JSON.parse(attempt);
        if (accept(o)) return o;
      } catch {
        // not this one
      }
    }
  }
  return null;
}

export function isTerminalResult(text) {
  return parseTerminalFencedJson(text, (o) => isResultShape(o)) !== null;
}

// The options handed to the SDK ARE the sandbox: the allowlist below defends predicates that any one of these
// lines can disconnect. `allowedTools: ['Bash']` pre-approves the shell, dropping `settingSources: []` lets a
// `.claude/settings.json` in the PR head add hooks that run before canUseTool, and `env: process.env` hands the
// agent every credential in the job. Built here, as a pure value, so the tests can assert on them — a mutation
// test showed all three surviving a green suite.
// Exported for the test that pins these two as REACHING the SDK: the resolved model and the turn cap are both
// computed carefully and were both droppable from the options with the whole suite green.
export const MODEL_FOR_TEST = () => MODEL;

export const MAX_TURNS_FOR_TEST = () => maxTurns();

// `canUseTool` as a hook. Only the DENY travels: an `allow` from a hook would skip the permission callback, and
// with it the input rewrite that neutralises `run_in_background` — so on allow the hook says nothing and the
// normal path decides. One predicate, expressed at both points the SDK offers, no second opinion.
export async function preToolUseGate(input) {
  const decision = await canUseTool(input.tool_name, input.tool_input ?? {});
  if (decision.behavior === 'deny') {
    return { hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: decision.message } };
  }
  return { continue: true };
}

export function agentQuery({ userPrompt, systemPrompt, abort, onStderr = () => {}, env = agentEnv() } = {}) {
  return {
    prompt: userPrompt,
    options: {
      model: MODEL,
      systemPrompt,
      // The base tool set is exactly these four (native builds otherwise omit Grep/Glob and expect Bash
      // find/grep). Nothing is pre-approved here — but whether a Read is ROUTED to `canUseTool` in default mode
      // is the SDK's decision, and its built-in rules may treat a read inside the working directory as needing no
      // permission at all. So the same gate is also installed as a PreToolUse hook, which runs for every tool call
      // before that decision: the path rules hold whichever way a release routes a Read.
      tools: ['Read', 'Grep', 'Glob', 'Bash'],
      allowedTools: [],
      hooks: { PreToolUse: [{ hooks: [preToolUseGate] }] },
      // SDK isolation mode: ignore every on-disk settings file. Otherwise a `.claude/settings.json` in the
      // PR head (or on the runner) could add permission rules or hooks that run before canUseTool.
      settingSources: [],
      permissionMode: 'default',
      canUseTool,
      maxTurns: maxTurns(),
      // Pinned, not left to the model's default: Opus 5.5 defaults to medium, a level below Opus 5's high,
      // so a model upgrade would otherwise quietly make the reviewer shallower.
      effort: 'high',
      abortController: abort,
      // Set after agentEnv(), which strips anything matching /TOKEN/ — including this one.
      env: { ...env, CLAUDE_CODE_MAX_OUTPUT_TOKENS: String(maxOutputTokens()) },
      cwd: agentCwd(),
      stderr: (d) => {
        onStderr(d);
        // Redacted like its buffered twin: this stream goes straight into a public run log.
        process.stderr.write(`[claude] ${redact(String(d))}`);
      },
    },
  };
}

// What survives the bell, in order of how much it can be trusted: a strictly terminal answer in the buffer; else
// a strictly terminal earlier answer, which the fallback path will use; else whatever the parser can read, which
// beats nothing but may be a result-shaped block the agent quoted from the diff. ONE rule, because the two
// deadline paths must agree: the abort branch fires while the agent is mid-generation (the common case) and used
// to keep a partial rewrite of an answer it had already finished.
export function salvageAtDeadline({ finalText, lastAnswer, isFinished, isSalvageable }) {
  if (isFinished(finalText)) return finalText;
  if (lastAnswer) return '';
  return isSalvageable(finalText) ? finalText : '';
}

// Two different questions, so two predicates. `isFinished` decides whether a segment a tool call discarded was a
// finished answer, and must stay strict (a result block quoted from the diff must not qualify). `isSalvageable`
// decides whether the text in hand at the deadline is worth keeping, and should be as tolerant as the parser that
// will read it — otherwise a complete, parseable review is thrown away for the "hit the time limit" note.
const reviewAnswerParses = (t) => {
  try {
    extractJson(t);
    return true;
  } catch {
    return false;
  }
};

export async function runAgent(userPrompt, budgetMs, systemPrompt = '', isFinished = isTerminalResult, isSalvageable = reviewAnswerParses) {
  const { query } = await import('@anthropic-ai/claude-agent-sdk');
  // Read here, not at module load: review-guide.md is PR-authored, and a PR that renames it used to kill the
  // module during evaluation — taking the --setup-failed reporter, which needs neither, down with it.
  const system = systemPrompt || buildSystemPrompt();
  let finalText = '';
  let lastAnswer = ''; // the most recent complete answer that a later tool call reset; a fallback for the turn-limit case
  let turns = 0;
  let resultSubtype = null;
  const stderrChunks = [];
  const startedAt = Date.now();
  // Out-of-band bound: fires even if the subprocess stalls without emitting a message.
  const abort = new AbortController();
  const deadlineTimer = setTimeout(() => abort.abort(new Error('review deadline reached')), budgetMs);
  const iterator = query(agentQuery({ userPrompt, systemPrompt: system, abort, onStderr: (d) => stderrChunks.push(d) }));
  try {
    for await (const msg of iterator) {
      // The message in hand is processed BEFORE the clock is read: an answer that lands in the same iteration as
      // the bell is then still available to isFinished below, rather than discarded unexamined.
      if (msg.type === 'assistant') {
        turns++;
        const content = msg.message?.content;
        if (Array.isArray(content)) {
          const { text, discarded } = accumulateFinalText(finalText, content, (name) => {
            // Log the tool name only — not its input, which can contain file paths / queries.
            console.log(`  [turn ${turns}] ${name}`);
          });
          finalText = text;
          // A tool call reset the buffer: remember what it held ONLY if it was a finished answer. Interstitial prose
          // ("let me check the callers…") precedes most tool calls and must not make a turn-limit failure recoverable.
          const finished = discarded.filter((d) => isFinished(d)).pop();
          if (finished) lastAnswer = finished;
        }
      } else if (msg.type === 'result') {
        resultSubtype = msg.subtype || null;
        if (resultSubtype && resultSubtype !== 'success') {
          console.warn(`Agent terminated: ${resultSubtype}`);
        }
      }
      if (Date.now() - startedAt > budgetMs) {
        // A run that already reported its own outcome is done: relabelling it `error_deadline` would discard a
        // complete review just because the bell rang while its result message was in flight.
        if (resultSubtype) break;
        console.warn(`Deadline of ${Math.round(budgetMs / 60000)} min reached after ${turns} turns; stopping the agent`);
        resultSubtype = 'error_deadline';
        finalText = salvageAtDeadline({ finalText, lastAnswer, isFinished, isSalvageable });
        if (typeof iterator.interrupt === 'function') await iterator.interrupt().catch(() => {});
        break; // closes the generator (and with it the agent subprocess)
      }
    }
  } catch (err) {
    if (abort.signal.aborted) {
      console.warn(`Deadline of ${Math.round(budgetMs / 60000)} min reached after ${turns} turns (agent aborted)`);
      return {
        finalText: salvageAtDeadline({ finalText, lastAnswer, isFinished, isSalvageable }),
        lastAnswer,
        turns,
        resultSubtype: 'error_deadline',
      };
    }
    err.capturedStderr = stderrChunks.join('');
    throw err;
  } finally {
    clearTimeout(deadlineTimer);
  }
  return { finalText, lastAnswer, turns, resultSubtype };
}
