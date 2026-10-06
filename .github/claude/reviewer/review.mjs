// The round. `runReview` composes the modules in this directory: read the PR, build the prompts, run the agent
// (agent.mjs) inside the sandbox (sandbox.mjs), key the findings (identity.mjs), verify the open ones (verify.mjs),
// reconcile with the threads on the PR, and write the summary (summary.mjs). This file owns the budgets and the
// order of operations; the seams are the other files.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { fetchPullRequestDiff, getPullRequest, listIssueComments, listReviewThreads, postInlineComment, replyToReviewComment, resolveReviewThread, setNetworkDeadline, unresolveReviewThread } from './github.mjs';
import { BASE, COMMIT, DRY_RUN, PR_NUMBER, num, requireEnv } from './config.mjs';
import { boundedDump, captureSecretValues, diffPath, mdPath, neutralizeMarkup, redact, safeRealpath, withoutWriteTokens } from './sandbox.mjs';
import { HARNESS_RESOLVED_MARKERS, MAX_INLINE, REOPENED_NOTE, SEVERITY_RANK, actionByFp, buildState, carriedRecords, closedRecords, duplicateNote, fingerprintOfThread, harnessClosed, isHarnessComment, keyFindings, openFindings, openFindingsBlock, planRound, readPriorState, rewordedNote, severityEmoji, threadAnchor, threadIdByFp } from './identity.mjs';
import { buildUserPrompt } from './prompts.mjs';
import { DEGRADABLE_SUBTYPES, FALLBACK_MODEL, FALLBACK_MODELS, MODEL, RANKED_MODELS, assertResultShape, extractJson, logAgentOutput, resolveModel, runAgent, setModel, shouldHardFail, wasTruncationRepaired } from './agent.mjs';
import { VERIFY_SYSTEM_PROMPT, applyVerification, buildVerifyPrompt, closeWithReason, parseVerifyResult, verdictsById } from './verify.mjs';
import { SETUP_NOTE_BUDGET_MS, appendNoteToSummary, explainFailure, recordExplainedOnPr, renderSummary, reportSetupFailure, summaryWriteFailed, upsertSummary } from './summary.mjs';

// Wall-clock bound for the agent, under the job's timeout-minutes: hitting it degrades to the "incomplete"
// note instead of a cancelled job that may have half-reconciled the PR.
// 12, not 14: this is the knob the summary tells a maintainer to raise, so it has to be the one that BINDS.
// With the job budget at 18 and the verify slice at 5, a 14-minute deadline was never reached — the review always
// stopped at 13 — and raising REVIEW_DEADLINE_MS changed nothing at all.
const DEADLINE_MS = num(process.env.REVIEW_DEADLINE_MS, 12 * 60 * 1000);

// The budget for the two model passes, measured from the start of runReview(). The review and the verification pass
// are both bounded by THIS, not by each other: taking the verify slice out of the review's own deadline meant a
// review that used its full 14 minutes left a negative verify budget, so the second pass was silently skipped on
// exactly the large PRs it was added for, falling back to "was not re-reported".
//
// It has to leave room inside the workflow's timeout-minutes for what this clock does NOT cover: the ~1 min of
// checkout, install and harness tests before node starts, and the reconcile phase afterwards, which posts up to
// MAX_INLINE comments plus a resolve and a reply per closed thread, each with its own 30 s timeout. Being
// cancelled mid-reconcile is the half-finished state the deadline exists to prevent, so the two model passes
// are bounded to 12 (the review's own DEADLINE_MS) + 5 (the verify slice) = 17 min, and with ~1 min of setup
// that leaves ~6 of the review step's 24 for reconcile — the STEP's cap is what binds here, not the job's 48,
// which is deliberately the looser of the two. That last figure is an ASSUMPTION, not a bound: nothing
// measures the clock during reconcile, and a pathological round (25 posts and dozens of replies, all slow)
// could exceed it. It errs safe — a cancelled job writes nothing rather than something wrong — and raising
// either budget means raising `timeout-minutes` in the workflow with it.
const JOB_BUDGET_MS = num(process.env.REVIEW_JOB_BUDGET_MS, 18 * 60 * 1000);

// What the WRITE phase may spend on the network after the two model passes are done. The phase itself is
// deliberately unclocked — a round cut off mid-reconcile is the half-finished state everything here avoids — but
// its GitHub calls need a retry budget of their own, and `JOB_BUDGET_MS` is already spoken for. The review step's
// cap in the workflow has to cover this as well as the budget above; `test/workflow.test.mjs` checks that it does.
const RECONCILE_NETWORK_MS = num(process.env.REVIEW_RECONCILE_NETWORK_MS, 4 * 60 * 1000);

const VERIFY_BUDGET_MS = num(process.env.REVIEW_VERIFY_BUDGET_MS, 5 * 60 * 1000);

export async function reconcile(currentByFp, threads, io, options = {}) {
  // No `provisional` here any more: this function closes nothing, so there was nothing for it to withhold — the
  // branch returned the identical object and differed only by a log line, while its comment went on describing a
  // resolve-stale-threads step that moved to the verification pass. `provisional` still means something in
  // `runReview`, which is where it gates that pass.
  const { priorState } = options;
  // `priorState` is legitimately null on a first round, so it cannot be defaulted — a default is exactly how a
  // refactor drops it silently and sends reconciliation back to marker archaeology. The KEY is required instead:
  // absent means someone stopped passing it, which is a crash the harness reports rather than a quiet regression.
  if (!('priorState' in options)) throw new Error('reconcile: priorState must be passed explicitly (null on a first round)');
  // Errors first: with MAX_INLINE in play, the findings a human most needs in context must get the slots.
  currentByFp = new Map([...currentByFp].sort(([, a], [, b]) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity]));
  // Which thread carries which finding: from the record when there is one, from the comment body when there is
  // not. Only threads we authored count either way — a missing author (a deleted account) is not ours. An
  // end-to-end round caught this still parsing bodies after `planRound` had moved: a thread whose body had been
  // edited was invisible here, so a returning finding was posted as new instead of reopening its own thread.
  const existingByFp = new Map();
  const ours = threads.filter((t) => isHarnessComment(t.firstCommentAuthor));
  for (const t of ours) {
    const fp = fingerprintOfThread(t, priorState);
    if (fp && !existingByFp.has(fp)) existingByFp.set(fp, t);
  }

  const stats = { posted: 0, kept: 0, reopened: 0, dismissed: 0, resolved: 0, reworded: 0 };
  const unpostable = [];
  const unpostableFps = new Set(); // the KEYS, so the record cannot disagree with what was actually attempted
  const liveFps = new Set(); // findings a thread still carries after this round — kept, reopened, or just posted
  const postedCommentIdByFp = new Map(); // fp -> the id of the comment this round created for it
  // Post the finding's CURRENT wording on a thread that does not already carry it. Compared in the form it
  // was posted in — bodies go out through `redact(neutralizeMarkup(...))` — which is what makes it
  // self-limiting: after the reply the thread contains that text, so a wording is never posted twice.
  //
  // CONTAINMENT, not resemblance, and the churn that costs is accepted deliberately. A ~0.9 similarity guard was
  // proposed to suppress near-identical rewordings; two wordings that differ by one word (`onStop` against
  // `onDestroy`) score above that, and the word they differ by is the whole finding. Measured on this PR across
  // 23 rounds and 150 threads: 6 replies, because a finding usually returns in the same words or is fixed.
  const sayCurrentWording = async (thread, f, fp) => {
    const bodies = [thread.firstCommentBody || '', ...(Array.isArray(thread.comments) ? thread.comments.map((c) => c.body || '') : [])];
    const rendered = redact(neutralizeMarkup(f.comment));
    if (bodies.some((b) => b.includes(rendered))) return;
    stats.reworded++;
    try {
      await io.reply(thread, redact(rewordedNote(neutralizeMarkup(f.comment))));
    } catch (e) {
      // This reply IS the safety net — it is what keeps a re-matched finding's current wording on the pull
      // request when the thread it was matched to says something else. A failed net used to be a warning and
      // nothing more, which left the new wording nowhere at all while the finding counted as carried over. So
      // the finding joins the unpostable list instead: its full text goes in the summary, which is where every
      // other finding that could not be put on a thread ends up.
      console.warn(`reworded note failed (fp:${fp}) — ${redact(e.message)}; listing the finding in the summary instead`);
      stats.reworded--;
      // The summary list only, not `unpostableFps`: those are the keys whose POST was refused, and this finding
      // does have a thread — the record still points at it, and the next round must look it up there rather than
      // treat it as never posted.
      unpostable.push(f);
    }
  };

  for (const [fp, f] of currentByFp) {
    const existing = existingByFp.get(fp);
    if (existing) {
      if (!existing.isResolved) {
        stats.kept++;
        liveFps.add(fp);
        // The thread stays as it is when it already says this — no churn for a finding that has not changed —
        // and otherwise the current wording goes on it. Whatever decided that this finding belongs here (a
        // fingerprint, or the agent's own `same_as`), a decision must not be able to bury text.
        await sayCurrentWording(existing, f, fp);
      } else if (harnessClosed(existing, HARNESS_RESOLVED_MARKERS, priorState)) {
        // We closed it (not re-reported, or verified fixed) and it is back: reopen it.
        try {
          await io.unresolve(existing);
          stats.reopened++;
          liveFps.add(fp); // reopened, so a duplicate of it has somewhere to point
          await io.reply(existing, REOPENED_NOTE).catch((e) => console.warn(`reopen note failed (fp:${fp}) — ${redact(e.message)}`));
          // The same rule as the kept branch. A finding that comes back RE-WORDED onto a thread we had closed
          // was unresolved, counted in `stats.reopened`, and its new text posted nowhere — the thread went on
          // showing the original wording. The invariant is not "a kept finding's text is never buried", it is
          // that no identity decision buries text, so it belongs to every branch that matches a finding to a
          // thread. (The conservation law could not see this: its oracle token survives rewording, so the
          // original comment still contained it and the law held vacuously here. Fixed there too.)
          await sayCurrentWording(existing, f, fp);
        } catch (e) {
          // The reopen failed (a stale REVIEW_RESOLVE_TOKEN is the likely reason), so the thread stays collapsed
          // as resolved while the finding is live again. Surface it in the summary body rather than leaving it
          // as a number in the counts line, exactly as a failed inline post does below.
          console.warn(`unresolve failed (fp:${fp}) — ${redact(e.message)}`);
          unpostable.push(f);
          unpostableFps.add(fp);
        }
      } else {
        // A human resolved it: that is a decision, not a fix. Don't nag — but don't drop it either. The finding
        // was reported again and is now invisible: no new comment (right, the thread is closed deliberately), no
        // reopen (right, that would be nagging), and until now no mention anywhere. It goes in the summary body,
        // where a maintainer can see the reviewer still considers it live without being pushed to reopen.
        unpostable.push(f);
        unpostableFps.add(fp);
        // One-time wrinkle on PRs already open when this harness landed: the previous version resolved threads
        // without leaving a note, so those carry no marker and are read here as human decisions — a finding
        // re-reported on such a thread is neither reopened nor re-posted. It cannot be told apart from a human
        // who resolved silently, and it self-heals on every PR opened afterwards.
        stats.dismissed++;
      }
      continue;
    }
    if (stats.posted >= MAX_INLINE) {
      unpostable.push(f);
      unpostableFps.add(fp);
      continue;
    }
    const body = redact(`${severityEmoji(f.severity)} **${f.severity.toUpperCase()}** — ${neutralizeMarkup(f.comment)}\n\n<!-- bp-ai-review-fp:${fp} -->`);
    try {
      // The created comment's id is kept, because the THREAD's id is not available this round: the thread listing
      // was read before any of this posted, so a finding posted now is recorded with `id: null` and its identity
      // next round rests entirely on the marker in its body — the archaeology the record exists to replace. One
      // maintainer edit of that body on the very next push made the thread unrecognisable and the finding got a
      // second comment. This id is the same number that comes back as `firstCommentId` on the thread, so the next
      // round can match on it while the record still has no thread id.
      const created = await io.post(f, body);
      if (created?.id) postedCommentIdByFp.set(fp, created.id);
      stats.posted++;
      liveFps.add(fp);
    } catch (e) {
      console.warn(`inline post failed ${boundedDump(f.file, 80)}:${f.line} — ${redact(e.message)}`);
      unpostable.push(f);
      unpostableFps.add(fp);
    }
  }

  // No loop over the threads this round did not re-report: this function does not close anything. Posting,
  // keeping and reopening are what it decides, and every close in the harness now comes from the verification
  // pass, which reads the code. `liveFps` is handed back so the caller can check that a finding the verifier
  // called a duplicate actually landed before closing the thread it duplicates.
  return { stats, unpostable, unpostableFps, liveFps, postedCommentIdByFp };
}

// What the review may spend: its own deadline, capped by the job budget minus the slice held back for the
// verification pass. Setup (the PR fetch, the diff, retries) has already run, so it is measured from `startedAt`.
export const reviewBudget = (startedAt, now = Date.now()) =>
  Math.max(60_000, Math.min(DEADLINE_MS, JOB_BUDGET_MS - (now - startedAt) - VERIFY_BUDGET_MS));

// The verification slice, bounded by what is left of the job budget rather than by the review's own deadline.
export const verifyBudget = (startedAt, now = Date.now()) =>
  Math.min(VERIFY_BUDGET_MS, JOB_BUDGET_MS - (now - startedAt) - 30_000);

// `runReview()` with one seam: the model call. Everything else — the GitHub client, the diff on disk, the budgets —
// stays real, so a test can drive the whole composition through a stubbed `fetch` and only fake the agent. Three
// separate mutations survived a green suite purely because they lived in these call sites and nothing could reach
// them; guarding each one was mitigation, this is the coverage.
export async function runReview({ agent: rawAgent = runAgent } = {}) {
  captureSecretValues(); // before anything is logged or posted, and before the write tokens leave the environment
  // Every call to the agent goes through the withholding, whichever implementation is in hand.
  const agent = (...args) => withoutWriteTokens(() => rawAgent(...args));
  // Before the --setup-failed branch too: NaN would otherwise reach listIssueComments(NaN), whose failure
  // appendNoteToSummary swallows — leaving exactly the silent red check that mode exists to prevent.
  if (!Number.isInteger(PR_NUMBER()) || PR_NUMBER() < 1) throw new Error(`PR_NUMBER must be a positive integer, got ${JSON.stringify(process.env.PR_NUMBER)}`);
  const setupFailedAt = process.argv.indexOf('--setup-failed');
  if (setupFailedAt !== -1) {
    requireEnv('GITHUB_TOKEN');
    requireEnv('PR_NUMBER');
    // This mode returns before the clock the rest of runReview() arms, so its ladders were bounded only by attempts
    // times timeout: a comment listing is up to 20 pages, each with 3 attempts of 30 s, and `outOfTime()` cannot
    // fire against an `Infinity` deadline — half an hour against the job's 48. The job would then
    // be cancelled and the PR would get no comment at all, which is the one thing this mode exists to prevent.
    // A note needs a read and a write, so it gets a minute and a half.
    setNetworkDeadline(Date.now() + SETUP_NOTE_BUDGET_MS);
    await reportSetupFailure(process.argv.slice(setupFailedAt + 1).join(' '));
    return;
  }
  requireEnv('ANTHROPIC_API_KEY');
  requireEnv('GITHUB_TOKEN');
  requireEnv('PR_NUMBER');
  requireEnv('COMMIT');
  const diffFile = diffPath();
  const startedAt = Date.now();
  // The GitHub client may not retry past the run's own budget: its ladders are otherwise bounded only by attempts
  // times timeout, which is time the review and verification passes have already been promised.
  //
  // Plus the reconcile allowance, because `JOB_BUDGET_MS` is exactly what the two model passes may spend — so on
  // a long round the clock was already expired when the WRITE phase began, and that phase is the round's only
  // durable output. Everything in it then ran with retries disabled: one attempt for the summary's stale-listing
  // re-check, and a transient 500 there made the round post a SECOND summary, which is two state records.
  setNetworkDeadline(startedAt + JOB_BUDGET_MS + RECONCILE_NETWORK_MS);
  setModel(await resolveModel());
  console.log(`Reviewing PR #${PR_NUMBER()} (base ${BASE()}, head ${COMMIT().slice(0, 8)}) with ${MODEL}`);

  const pr = await getPullRequest(PR_NUMBER());
  // Fail closed: without the thread list we can't de-duplicate, and re-posting every finding would
  // spam the PR. Post the summary alone and let the next run reconcile.
  // The record the last round left. One extra read, retried and inside the network budget, and it replaces
  // guessing our own history from these comments.
  let stateRecord = null;
  // "The read failed" and "there is no record" are different facts, and treating them alike destroyed the
  // record: a round that could not READ it still wrote a fresh one over the top, so one transient 500 cost every
  // close the harness remembered and every thread identity a maintainer's edit had erased from the bodies. The
  // failure is carried to the write instead, where the record that IS in the comment can be kept.
  let recordReadFailed = false;
  // Kept for the summary write at the end of the round, so the comments are paginated once and both decisions —
  // which record this round starts from, and which comment it writes back into — are made from the same read.
  let listing = null;
  try {
    const { comments, truncated } = await listIssueComments(PR_NUMBER());
    listing = { comments, truncated, readAt: Date.now() };
    stateRecord = await readPriorState(comments);
    if (stateRecord) console.log(`Prior state: ${Object.keys(stateRecord.findings).length} finding(s) recorded at ${stateRecord.commit.slice(0, 8) || 'an unknown commit'}`);
    else if (truncated) {
      // "No record" and "we stopped looking" are different facts, and this is the second door through which
      // they were being conflated: an over-budget or capped listing that missed the summary would have the
      // round build a fresh record over the top of the real one.
      recordReadFailed = true;
      console.warn('The comment listing was truncated before a state record was found; treating it as a failed read');
    } else console.log('No prior state record on this PR; falling back to the comment markers');
  } catch (e) {
    recordReadFailed = true;
    console.warn(`Could not read the prior state record (${redact(e.message)}); falling back to the comment markers, and this round will merge into whatever record the summary still holds`);
  }

  let threads = null;
  try {
    const listed = await listReviewThreads(PR_NUMBER());
    // A list that stopped early is not a list this round can reconcile against: every thread past the cut looks
    // like a finding with no comment and would get a second one. Treated exactly like a failed read.
    if (listed.truncated) console.warn('The thread listing was truncated; treating it as unavailable rather than posting duplicates');
    else threads = listed.threads;
  } catch (e) {
    // Not fatal here any more: the review can still run, it just cannot be told what is already open, and the
    // reconcile below stops rather than risk duplicates. Read BEFORE the agent so the prompt can carry the open
    // findings — the agent naming one is what replaced the harness inferring identity from a hash.
    console.warn(`listReviewThreads failed: ${redact(e.message)}; reviewing without the open-findings list`);
  }

  const diff = await fetchPullRequestDiff(PR_NUMBER());
  // The directory, because RUNNER_TEMP is guaranteed to exist only in CI. Locally the documented invocation sets
  // it to a path nothing creates, so the run died with ENOENT here — after fetching the PR and the diff, and
  // outside DRY_RUN after `explainFailure` had already posted a "did not run" note on a real pull request.
  mkdirSync(dirname(diffFile), { recursive: true });
  writeFileSync(diffFile, diff);
  // Counted once and told to the agent: the Read tool refuses a file over ~256 KB in one call, and this PR's
  // own diff is 493 KB. Without the size in the prompt the agent discovers that by trial, which costs a turn
  // on exactly the large PRs where the deadline is already tight — found by the harness reviewing itself.
  const diffLineCount = diff.split('\n').length;
  console.log(`Diff: ${diffLineCount} lines, ${diff.length} bytes -> ${diffFile}`);

  // Numbered once, and used twice: in the prompt, and to read back a `same_as` claim.
  const open = openFindings(threads || [], stateRecord);
  const claims = new Map(open.map((f) => [f.n, f.fp]));
  if (open.length) console.log(`Telling the reviewer about ${open.length} finding(s) still open from earlier pushes`);

  let agentRun;
  try {
    // The time that is left, not the whole budget: fetching the PR, the diff (up to 4x the API timeout, retried)
    // and writing it to disk all happen first, and a deadline measured from here could outlast the job's own
    // timeout — a cancelled job is the half-reconciled, comment-less outcome the deadline exists to prevent.
    agentRun = await agent(buildUserPrompt(pr, diffFile, diff.length, diffLineCount, openFindingsBlock(open)), reviewBudget(startedAt));
    if (shouldHardFail(agentRun)) {
      throw new Error(`agent ended with ${agentRun.resultSubtype} and no output`);
    }
  } catch (e) {
    // A freshly listed model can be unavailable to this account; try the known-good id once — but only for
    // that class of failure. Rate limits, turn limits and network errors would just fail again at double cost.
    // Both halves required: the error must be about the model AND say it can't be used.
    const msg = e.message || '';
    const modelUnavailable = /\bmodel\b/i.test(msg) && /not[_ ]?found|404|does not exist|unsupported|not available|not (?:have|permitted|authorized)/i.test(msg);
    // A DIFFERENT release, not merely a different id. The Models API lists dated snapshots of the same release
    // next to its alias (`claude-opus-5-20260601` after `claude-opus-5`), so "the runner-up" was usually the same
    // model under another name — and if the failure really is "this account cannot use Opus 5", that fails for the
    // same reason and the round is spent. The fallback-list path already behaved this way, because that list is
    // one id per release; this makes the API path match it.
    // The dated snapshot and its alias are ONE release: strip a trailing date (6+ digits) and the family prefix,
    // so `claude-opus-5-20260601` and `claude-opus-5` both reduce to `5`, while `claude-opus-4-8` stays `4-8`.
    const release = (id) => String(id || '').replace(/-\d{6,}$/, '').replace(/^claude-[a-z]+-/, '') || String(id);
    const retryModel =
      RANKED_MODELS.find((id) => release(id) !== release(MODEL)) ||
      FALLBACK_MODELS.find((id) => release(id) !== release(MODEL)) ||
      FALLBACK_MODEL;
    if (!modelUnavailable || retryModel === MODEL || process.env.REVIEW_MODEL) throw await explainFailure(e);
    console.warn(`Run with ${MODEL} failed (${redact(msg)}); retrying once with ${retryModel}`);
    setModel(retryModel);
    try {
      agentRun = await agent(buildUserPrompt(pr, diffFile, diff.length, diffLineCount, openFindingsBlock(open)), reviewBudget(startedAt));
      // The same gate as the first attempt: a retry that ends with an unexpected subtype and no output is a
      // failure, not a degrade.
      if (shouldHardFail(agentRun)) throw new Error(`agent ended with ${agentRun.resultSubtype} and no output`);
    } catch (e2) {
      throw await explainFailure(e2);
    }
  }
  const { finalText, lastAnswer, turns, resultSubtype } = agentRun;
  console.log(`Agent finished in ${turns} turns (${resultSubtype || 'no-result'})`);

  // Parse the agent's JSON. If it truncated (e.g. hit the turn limit on a large PR) or
  // produced malformed output, degrade gracefully: post a visible note and exit 0 rather
  // than hard-failing the check with nothing.
  let parsed;
  let provisional = false;
  let provisionalCause = 'turns';
  try {
    if (!finalText) throw new Error('agent produced no text output');
    // assertResultShape throws before the assignment, so `parsed` stays unset and the degrade path below
    // (gated on `!parsed`) still runs.
    parsed = assertResultShape(extractJson(finalText));
    // Three ways an answer that looks complete is not, each of which would otherwise let a partial finding list
    // auto-resolve every earlier finding it fails to mention: the clock cut the run short; the turn limit did; or
    // the answer was truncated mid-object and the parser closed it for us. The deadline salvage gate is as
    // tolerant as the parser too, so what it kept may be a result-shaped block quoted from the diff rather than
    // the agent's own conclusion. Post it, say so, and resolve nothing on its authority.
    provisional = DEGRADABLE_SUBTYPES.has(resultSubtype) || wasTruncationRepaired(parsed);
    if (provisional) provisionalCause = wasTruncationRepaired(parsed) ? 'truncated' : resultSubtype === 'error_deadline' ? 'deadline' : 'turns';
  } catch (e) {
    // Turn-limit fallback: the agent finished an answer, made one more tool call (with or without trailing prose)
    // and was cut off. Use the remembered terminal answer, flagged provisional: it may have been superseded by
    // what the agent was about to check, so the summary says so and stale threads are not resolved from it.
    if (lastAnswer && (resultSubtype === 'error_max_turns' || resultSubtype === 'error_deadline')) {
      try {
        parsed = assertResultShape(extractJson(lastAnswer));
        provisional = true;
        provisionalCause = resultSubtype === 'error_deadline' ? 'deadline' : 'turns';
        console.warn(`${resultSubtype === 'error_deadline' ? 'Time' : 'Turn'} limit hit after a tool call; using the last complete answer (provisional): ${redact(e.message)}`);
        if (finalText) logAgentOutput('Agent output, superseded by the last complete answer', finalText);
      } catch {
        // no usable remembered answer either: degrade below
      }
    }
    if (!parsed) {
      const reason =
        resultSubtype === 'error_max_turns'
          ? 'hit the turn limit before finishing — likely a large PR. Bump `REVIEW_MAX_TURNS` or split the PR into smaller ones.'
          : resultSubtype === 'error_deadline'
            ? 'hit the time limit before finishing — likely a large PR. Raise `REVIEW_DEADLINE_MS`, `REVIEW_JOB_BUDGET_MS` with it (the review is capped by the job budget minus the verification slice), and `timeout-minutes` in the workflow, which bounds them both — or split the PR.'
            : `could not produce a structured result (${redact(e.message)}).`;
      console.warn(`Review incomplete: ${redact(reason)}`);
      // The whole answer (bounded, redacted): a 400-char tail was not enough to diagnose why extraction failed. An
      // answer a later tool call reset is still the best evidence there is when the final buffer is empty.
      if (finalText) logAgentOutput('Agent output', finalText);
      else if (lastAnswer) logAgentOutput('Agent output, the answer before its last tool call', lastAnswer);
      if (!DRY_RUN()) {
        // Appended, not overwritten: a later push timing out must not wipe the review a human reads.
        await appendNoteToSummary(`> ⚠️ **This round did not finish:** the reviewer ${reason}`, '## ⚠️ Claude PR Review — incomplete');
      }
      return;
    }
  }

  // Current findings, de-duplicated by fingerprint.
  const VALID_SEVERITY = new Set(['info', 'warn', 'error']);
  const valid = [];
  let dropped = 0;
  for (const f of parsed.findings) {
    // Before anything is written to it: `isResultShape` asserts only that `findings` is an array, so an element
    // can be null, a string, or an object whose `comment` is not one — and assigning `f.line` to a primitive
    // throws in strict mode, AFTER the parse's try/catch, taking a complete answer to a red check. Discarded and
    // counted instead, which is what the summary's "discarded as malformed" line promises.
    if (!f || typeof f !== 'object' || Array.isArray(f) || typeof f.comment !== 'string') {
      dropped++;
      continue;
    }
    f.line = Number(f.line);
    f.file = typeof f.file === 'string' ? f.file.replace(/^\.\//, '') : '';
    if (!f.file || !Number.isInteger(f.line) || f.line < 1 || !f.comment || !VALID_SEVERITY.has(f.severity)) {
      dropped++;
      continue;
    }
    // A control character in `file` has no legitimate use and this string reaches the run log, where a newline
    // would put model-authored text at the start of a line — and the runner reads `::workflow-command::` there.
    // The agent dump is already bracketed with `::stop-commands::` for exactly this; the warnings that name a
    // file were the sinks that bypassed it. `set-env`/`add-path` are disabled, so the impact is log spoofing on
    // a public log rather than execution, and the fix belongs where the finding is validated.
    if (/[\x00-\x1f\x7f]/.test(f.file)) {
      console.warn(`Dropped a finding whose file name holds a control character (${boundedDump(f.file, 80)})`);
      dropped++;
      continue;
    }
    valid.push(f);
  }
  if (dropped) console.warn(`Dropped ${dropped} malformed finding(s) (missing field or invalid severity); the summary carries the count`);
  // Keyed once, with whatever is in hand. The threads are read before the agent runs (the prompt carries the
  // open findings), so a dry run has them too — an earlier comment here claimed otherwise and left DRY_RUN
  // exercising a different keying path from production: no collision salt, and a `same_as` claim never applied,
  // in the one mode the README recommends for local iteration.
  let currentByFp = keyFindings(valid, threads || [], stateRecord, claims);
  parsed.findings = [...currentByFp.values()]; // summary counts reflect what is actually posted

  if (DRY_RUN()) {
    console.log('\n===== DRY RUN =====');
    for (const [fp, f] of currentByFp) {
      console.log(`${severityEmoji(f.severity)} ${boundedDump(f.file, 120)}:${f.line} [${fp}] ${boundedDump(f.comment)}`);
    }
    console.log('\n--- summary ---');
    console.log(renderSummary(parsed, { posted: 0, kept: 0, reopened: 0, dismissed: 0, resolved: 0 }, [], { provisional, provisionalCause, dropped }));
    return;
  }

  // Prior threads we created (identified by the fp marker on their first comment).
  // Without the thread list this round cannot tell a new finding from one that already has a comment, and
  // re-posting every finding would spam the PR: say so and leave it to the next push, which is what this path
  // has always done — only now the review itself has already happened.
  if (!threads) {
    await upsertSummary(
      [
        // The findings themselves, not just their count: this path posts nothing inline, so the summary is the
        // only place the round's output can appear. "The next push will post them" assumes there is a next
        // push, and on a PR about to merge there is not — the whole round would have gone missing, which is the
        // one thing this harness is not allowed to do.
        renderSummary(parsed, { posted: 0, kept: 0, reopened: 0, dismissed: 0, resolved: 0 }, [...currentByFp.values()], { provisional, provisionalCause, dropped }),
        '',
        '> ⚠️ Could not read existing review threads on this run, so nothing was posted inline (a second comment on a thread that already has one is worse); every finding is listed above instead.',
      ].join('\n'),
      // The record this round READ, written back unchanged: this write replaces the comment the record lives in.
      stateRecord,
      { mergeExistingRecord: recordReadFailed, listing },
    ).catch(summaryWriteFailed);
    return;
  }

  const io = {
    post: (f, body) => postInlineComment({ prNumber: PR_NUMBER(), commitId: COMMIT(), path: f.file, line: f.line, body }),
    // Rejects rather than resolving when there is nothing to reply TO. A thread's `firstCommentId` is null when
    // the opening comment is not in the `first` selection (it can be deleted), and a silent success there made
    // three callers lie: `closeWithReason` reported the reason as posted and left the thread resolved with
    // nothing on it, `sayCurrentWording` counted a re-wording that reached nobody instead of listing the finding
    // in the summary, and the reopen note was skipped so an auto-resolve marker stayed the last word. Every one
    // of those callers already handles a refused reply; none of them could handle a reply that pretended.
    reply: (t, body) =>
      t.firstCommentId ? replyToReviewComment(PR_NUMBER(), t.firstCommentId, body) : Promise.reject(new Error(`thread ${t.id} has no comment to reply to`)),
    resolve: (t) => resolveReviewThread(t.id),
    unresolve: (t) => unresolveReviewThread(t.id),
  };

  // Second pass: judge the findings earlier runs left open against the code as it stands, instead of inferring from
  // "the fresh review did not mention it again". Only threads this harness opened, that are still open, and that the
  // fresh run did not re-report (a re-report is already an answer). Skipped on a provisional result or a thin budget.
  let previously = [];
  let verified = false;
  let verifiedClosedIds = new Set();
  let pendingDuplicates = []; // closes the verifier judged, applied only once their replacement has landed
  // A finding whose line drifted (the usual outcome of fixing something above it) gets a NEW fingerprint, so the
  // fresh run posts a new comment while the old thread is neither re-reported nor closed — two threads for one
  // issue. That is one of the things the verification pass answers now: it is shown the findings this push
  // reports for the same file and can call the old thread a `duplicate` of one of them. The harness used to
  // decide it here from a similarity score over the comment texts, and two genuinely different findings in one
  // file measure 0.889 against a 0.5 bar — a live finding retired unverified under a note claiming it had moved.
  // Harness-authored threads only, like reconcile's own map: the marker is a public string, so a comment from
  // anyone else carrying one must not decide which findings count as new.
  const { identities, toVerify, overflow } = planRound({ threads, currentByFp, priorState: stateRecord });
  const verifySlice = verifyBudget(startedAt);
  if (toVerify.length && (provisional || verifySlice <= 60_000)) {
    // Say why in the log: silently falling back to "was not re-reported" is how this pass came to look like it
    // was working on the large PRs where it was in fact being skipped.
    console.warn(
      provisional
        ? `Verification skipped: the result is provisional, so ${toVerify.length} open finding(s) go unjudged this round`
        : `Verification skipped: only ${Math.round(verifySlice / 1000)}s of the job budget left for ${toVerify.length} open finding(s)`,
    );
  }
  if (!provisional && toVerify.length && verifySlice > 60_000) {
    console.log(`Verifying ${toVerify.length} open finding(s) from earlier runs against ${COMMIT().slice(0, 8)}`);
    try {
      const numbered = toVerify.map((t, i) => ({ id: i + 1, thread: t, identity: identities.get(t.id) }));
      // A finished verifier answer has a different shape from a review's, so the deadline path is told how to
      // recognise one — otherwise a complete verdict list arriving near the bell would be discarded and these
      // threads would fall back to the fingerprint heuristic, unverified.
      const verifyFinished = (t) => parseVerifyResult(t) !== null;
      const run = await agent(buildVerifyPrompt(numbered, COMMIT(), pr.author, currentByFp), verifySlice, VERIFY_SYSTEM_PROMPT, verifyFinished, verifyFinished);
      // `verifyFinished` gates what runAgent remembers, so lastAnswer here is a verdict list, not a review
      // result — usable when the deadline landed after a complete list but before the run ended.
      const parsedThreads = parseVerifyResult(run.finalText || run.lastAnswer || '');
      if (!parsedThreads) throw new Error('no parseable {threads:[...]} in the verifier output');
      const applied = await applyVerification(verdictsById(parsedThreads), numbered, io, { commit: COMMIT(), prAuthor: pr.author, currentByFp });
      verifiedClosedIds = applied.closedIds;
      pendingDuplicates = applied.duplicates;
      previously = applied.rows.concat(
        overflow.map((t) => ({ label: `\`${mdPath(t.path)}:${threadAnchor(t).line ?? '?'}\``, status: 'open', note: 'not checked this round' })),
      );
      verified = true;
      console.log(`Verification: ${applied.stats.verifiedFixed} fixed, ${applied.stats.dropped} no longer apply, ${applied.stats.closedByHuman} closed by a maintainer, ${applied.stats.stillOpen} still open${applied.duplicates.length ? `, ${applied.duplicates.length} duplicate(s) awaiting their replacement` : ''}`);
    } catch (e) {
      // Never fail the review over the second pass: fall back to the fingerprint heuristic below.
      console.warn(`Verification pass skipped: ${redact(e.message || String(e))}`);
    }
  }

  if (toVerify.length && !verified) {
    // The pass was skipped or failed, and nothing else closes a thread now, so the summary has to show these as
    // unjudged instead of rendering no table at all and leaving a maintainer to assume they were dealt with.
    previously = previously.concat(
      [...toVerify, ...overflow].map((t) => ({
        label: `\`${mdPath(t.path)}:${threadAnchor(t).line ?? '?'}\``,
        status: 'open',
        note: 'not checked this round',
      })),
    );
  }

  const { stats, unpostable, unpostableFps, liveFps, postedCommentIdByFp } = await reconcile(currentByFp, threads, io, {
    priorState: stateRecord,
  });

  // The verifier's duplicate closes, applied last: a thread may only be closed in favour of a comment that is
  // really there, and until reconcile has run "the finding it duplicates" is only an intention. A post can 422
  // on a line outside the diff, hit the inline cap, or fail outright — closing the old thread then would lose
  // the finding twice over.
  const duplicateClosed = new Set();
  for (const d of pendingDuplicates) {
    if (!liveFps.has(d.fp)) {
      console.warn(`duplicate kept open (${d.label}): the finding it duplicates is not live after this round`);
      previously.push({ label: d.label, status: 'open', note: 'reported as a duplicate, but the finding it duplicates never landed — left open', superseded: true });
      continue;
    }
    try {
      const { closed, unexplained } = await closeWithReason(io, d.thread, redact(duplicateNote(d.line, d.evidence)));
      const dupNote = `duplicate of the finding reported at line ${d.line}`;
      if (!closed) {
        previously.push({ label: d.label, status: 'open', note: `${dupNote}, but the reply saying so could not be posted — left open`, superseded: true });
        continue;
      }
      duplicateClosed.add(d.thread.id);
      stats.resolved++;
      previously.push({ label: d.label, status: 'resolved', note: unexplained ? `${dupNote} (the reply saying so could not be posted)` : dupNote, superseded: true });
    } catch (e) {
      console.warn(`duplicate close failed (${d.label}) — ${redact(e.message)}`);
      previously.push({
        label: d.label,
        status: 'open',
        note:
          e?.stage === 'unreplyable'
            ? `duplicate of another finding this push, but ${e.message} — left for a human`
            : 'duplicate of another finding this push, but this thread could not be resolved',
        superseded: true,
      });
    }
  }

  // The review itself succeeded by this point; a flaky comments API must not turn the check red.
  const verificationState = verified ? 'verified' : toVerify.length === 0 ? 'none-open' : 'unknown';
  // What this round did, written down for the next one rather than left to be re-derived from these comments.
  const closed = closedRecords({ identities, threads, verifiedClosedIds, duplicateClosedIds: duplicateClosed });
  const roundState = buildState({
    commit: COMMIT(),
    currentByFp,
    threadIdByFp: threadIdByFp(threads, stateRecord),
    commentIdByFp: postedCommentIdByFp,
    priorState: stateRecord,
    actions: actionByFp({ unpostableFps, currentByFp }),
    closed,
    carried: carriedRecords({ identities, threads, currentByFp, closed, priorState: stateRecord, commit: COMMIT() }),
  });
  await upsertSummary(renderSummary(parsed, stats, unpostable, { provisional, provisionalCause, previously, verificationState, dropped }), roundState, {
    mergeExistingRecord: recordReadFailed,
    listing,
  }).catch(summaryWriteFailed);
  console.log(
    `Reconcile: ${stats.posted} new, ${stats.kept} kept, ${stats.reworded} reworded, ${stats.reopened} reopened, ${stats.dismissed} dismissed, ${stats.resolved} resolved, ${unpostable.length} unpostable`,
  );
  recordExplainedOnPr(); // the summary is on the PR, so the workflow's fallback note has nothing to add
  console.log(`Done. Verdict: ${parsed.verdict}`);
  // Advisory by design: exit 0 regardless of verdict so the review never blocks a merge.
  // To make it a hard gate (failed check that blocks merge on a "fail" verdict),
  // exit 1 here when parsed.verdict === 'fail'.
}

// Run only when executed directly (not when imported by a test). argv[1] is resolved because the workflow
// invokes this file by relative path, and both sides are realpath'd: comparing a lexical path against this
// module's real path would silently evaluate false when any component is a symlink, and the step would then
// exit 0 with no review at all.
const invokedDirectly = safeRealpath(resolve(process.argv[1] ?? '')) === safeRealpath(fileURLToPath(import.meta.url));

if (invokedDirectly) runReview().catch(async (err) => {
  // Say so on the PR before failing, whatever went wrong and wherever it happened — the setup calls before the
  // agent runs (the PR fetch, the diff fetch, writing it to disk) are outside runReview()'s own degrade paths, and a
  // red check with no comment is the invisible failure this harness exists to avoid. upsertSummary is an upsert,
  // so a second call from here is harmless when runReview() already explained itself.
  await explainFailure(err).catch(() => {});
  console.error('Fatal:', redact(err.stack || String(err)));
  if (err.capturedStderr) {
    console.error('--- claude stderr ---');
    console.error(boundedDump(err.capturedStderr));
  }
  process.exit(1);
});
