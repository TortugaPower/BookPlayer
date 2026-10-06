// The sticky summary comment: rendering, the state record it carries, the size budget, the notes appended when
// a round could not finish, and `upsertSummary` — the write that must never produce a second summary.

import { appendFileSync } from 'node:fs';
import { listIssueComments, postIssueComment, updateIssueComment } from './github.mjs';
import { DRY_RUN, PR_NUMBER, RUN_URL } from './config.mjs';
import { boundedDump, neutralizeMarkup, redact } from './sandbox.mjs';
import { GITHUB_COMMENT_LIMIT, MARKER_FAILURE_NOTE, MARKER_SUMMARY, MAX_INLINE, MAX_STATE_BYTES, MAX_STATE_MARGIN, STATE_MARKER, decodeState, encodeState, isHarnessComment, severityEmoji } from './identity.mjs';
import { MODEL } from './agent.mjs';

// `verificationState`, not `priorState`: this one is a three-valued STRING about the verification pass, while
// `priorState` everywhere else in this file is the decoded state record. They were both called `priorState`, and
// a refactor that passed one where the other belongs would type-check, run, and quietly send reconciliation back
// to reading markers out of comment bodies — which is what `reconcile`'s explicit `'priorState' in options` guard
// exists to stop.
// Model text that lands INSIDE the summary's `<details>` block. `neutralizeMarkup` stops an HTML comment; a
// finding whose text contains `</details>` — plausible when the reviewer is reviewing this file — would close the
// block early, spill the rest of the list and the footer outside it, and skew the open-minus-close count
// `closeUnbalancedDetails` trims by. Only those two tags are touched, so a code span in the prose stays readable.
const mdDetails = (s) => neutralizeMarkup(String(s)).replace(/<(\/?)(details|summary)\b/gi, '&lt;$1$2');

export function renderSummary(result, stats, unpostable, { provisional = false, provisionalCause = 'turns', previously = [], verificationState = 'unknown', dropped = 0 } = {}) {
  const emoji = result.verdict === 'fail' ? '🔴' : result.verdict === 'warn' ? '🟡' : '✅';
  const counts = result.findings.reduce(
    (a, f) => ({ ...a, [f.severity]: (a[f.severity] || 0) + 1 }),
    {},
  );
  const countLine =
    ['error', 'warn', 'info'].filter((s) => counts[s]).map((s) => `${counts[s]} ${s}`).join(' · ') ||
    'no findings';
  // Closed by the verification pass: reconcile's own `resolved` counter does not see these.
  // Rows this round closed itself are excluded (the `superseded` flag marks them, whichever kind of carrier they
  // followed): reconcile already counted those threads in `stats.resolved`, and nothing verified them — counting
  // them here reported one closure twice, once as "verified".
  const verifiedClosed = previously.filter((r) => r.status === 'resolved' && !r.superseded).length;

  const lines = [
    `## ${emoji} Claude PR Review — \`${result.verdict.toUpperCase()}\``,
    '',
    neutralizeMarkup(result.summary),
    '',
    `**Findings:** ${countLine}`,
  ];
  if (dropped) {
    // The one way a reported finding could leave the pull request with no trace: a finding with no usable file,
    // line, comment or severity is discarded before keying, and until this line it was named in the run log
    // only. A maintainer reading the summary could not tell it had happened. The text stays in the log — it is
    // model output that failed validation, so it is not posted — but the COUNT is part of the round's account.
    lines.push('', `> ⚠️ ${dropped} reported finding${dropped === 1 ? ' was' : 's were'} discarded as malformed (no usable file, line, comment or severity) and can be read in the run log only.`);
  }

  if (previously.length) {
    const icon = { resolved: '✅', open: '🟡' };
    lines.push(
      '',
      '### Previously raised',
      '',
      '| Finding | Status |',
      '| --- | --- |',
      ...previously.map((r) => `| ${r.label} | ${icon[r.status] || '🟡'} ${r.note} |`),
    );
    const settled = previously.every((r) => r.status === 'resolved');
    if (settled && result.findings.length === 0) {
      lines.push('', '**Converged:** nothing new this round, and every earlier finding is settled.');
    }
  } else if (result.findings.length === 0 && verificationState === 'none-open' && !provisional) {
    // Not on a provisional result: the banner two lines down says this finding list may be partial, and
    // "nothing new, and nothing left open" next to it claims exactly what the banner disclaims.
    // Only when the harness positively knows there was nothing left open — never when the verification pass was
    // skipped or failed, where an empty table means "unknown", not "nothing".
    lines.push('', '**Converged:** nothing new this round, and no earlier finding is open.');
  }

  if (provisional) {
    // Three different causes, and the knob differs for each — the wrong knob is worse than no knob.
    const BANNER = {
      truncated:
        'The reviewer\'s answer was cut off mid-JSON and the harness closed it, so this finding list is partial: ' +
        'no earlier finding was resolved from it. If it repeats, ask for fewer findings or split the PR.',
      deadline:
        'The reviewer hit its time limit before finishing; this is the last complete answer it produced, so no ' +
        'earlier finding was resolved from it. Raise `REVIEW_DEADLINE_MS` — and `REVIEW_JOB_BUDGET_MS` with it, ' +
        'since the review may not exceed the job budget minus the verification slice, and `timeout-minutes` in ' +
        'the workflow, which bounds them both — or split the PR.',
      turns:
        'The reviewer hit its turn limit before finishing; this is the last complete answer it produced, so no ' +
        'earlier finding was resolved from it. Bump `REVIEW_MAX_TURNS` or split the PR.',
    };
    lines.push('', `> ⚠️ ${BANNER[provisionalCause] || BANNER.turns}`);
  }

  if (unpostable.length) {
    lines.push(
      '',
      `<details><summary>Findings not visible inline (no line in this diff, beyond the ${MAX_INLINE}-comment cap, a comment the API refused, on a thread that could not be reopened, or on one a maintainer had the last word on)</summary>`,
      '',
      ...unpostable.map((f) => `- ${severityEmoji(f.severity)} \`${mdDetails(String(f.file).replace(/`/g, ''))}:${f.line}\` — ${mdDetails(f.comment)}`),
      '',
      '</details>',
    );
  }

  lines.push(
    '',
    `<sub>Model \`${MODEL}\`${RUN_URL() ? ` · [run log](${RUN_URL()})` : ''} · ${stats.posted} new · ${stats.kept} carried over${verifiedClosed ? ` · ${verifiedClosed} verified closed` : ''}${stats.reworded ? ` · ${stats.reworded} re-worded on their own thread` : ''}${stats.reopened ? ` · ${stats.reopened} reopened` : ''}${stats.dismissed ? ` · ${stats.dismissed} on threads a maintainer had the last word on` : ''} · ${stats.resolved} resolved · advisory (a human should still review). Findings are de-duplicated across pushes; an earlier finding closes only when the verification pass judges it against the current code — fixed, no longer applicable, accepted by a maintainer, or a duplicate of a finding reported on this push.</sub>`,
    '',
    MARKER_SUMMARY,
  );
  return lines.join('\n');
}

// How old a comment listing may be before the summary write re-checks whether somebody else posted one. A round
// reads it at the start and writes at the end, minutes apart; the note path reads and writes in the same breath.
const STALE_LISTING_MS = 60_000;

// What the summary half may use: the whole limit, less the record's budget and a margin.
const MAX_COMMENT = GITHUB_COMMENT_LIMIT - MAX_STATE_BYTES - MAX_STATE_MARGIN;

// GitHub rejects a comment over 65 536 characters. renderSummary inlines the full text of every finding that
// could not be attached inline, so a run with many findings can reach that — and the post would throw, the caller
// would log a warning, and the PR would carry no summary at all. Trim instead, keeping the marker (the upsert
// finds the comment by it) and a line saying what happened.
// The closers a cut needs so that whatever follows it is not rendered inside a collapsed element. Shared by
// the two paths that trim a summary: the second one was fixed for this and the first was not, which is exactly
// how a fix in one branch fails to be a fix in the other.
export function closeUnbalancedDetails(text) {
  const open = (String(text).match(/<details>/g) || []).length - (String(text).match(/<\/details>/g) || []).length;
  return open > 0 ? '</details>\n'.repeat(open) : '';
}

export function boundedSummaryBody(body, max = MAX_COMMENT) {
  if (body.length <= max) return body;
  // Cut at a line boundary, then close whatever the cut left open. The one thing that makes a body reach this
  // limit is the `<details>` list of findings that could not go inline — so the cut lands INSIDE that element,
  // and everything appended after it (the warning saying the summary was trimmed) renders inside a collapsed
  // block, which is to say invisibly. Reproduced in the suite on a 110 KB body of 900 unpostable findings.
  // The repair and the notice are part of what has to FIT: appending them after cutting at `max` returned more
  // than `max`, without bound — 11 characters per unbalanced tag, and model-authored text can hold hundreds.
  // Measured: max=5000 returning 5217, and end to end a 72 443-character comment that GitHub rejects outright,
  // so the round writes neither a summary nor a record. So the cut is made, the repair measured, and the cut
  // made again with room for it.
  const cutTo = (limit) => {
    const raw = body.slice(0, Math.max(0, limit));
    return raw.slice(0, Math.max(raw.lastIndexOf('\n'), 0)) || raw;
  };
  const tail = `\n\n> ⚠️ This summary was trimmed to fit GitHub's comment limit; the run log has the rest.\n\n${MARKER_SUMMARY}`;
  let cut = cutTo(max - tail.length);
  // One correction is enough in principle (fewer characters cannot open more tags), but the loop is cheap and
  // makes the bound a fact rather than an argument: it stops when the whole thing fits.
  for (let i = 0; i < 8; i++) {
    const closers = closeUnbalancedDetails(cut);
    if (cut.length + closers.length + tail.length <= max) return `${cut}\n${closers}${tail}`.replace(/\n\n\n+/g, '\n\n');
    cut = cutTo(max - tail.length - closers.length - 1);
  }
  return `${cut}${tail}`.slice(0, max);
}

// The final comment body: the summary, trimmed to fit, with the state record appended AFTER that trim. Inside it,
// a long summary would cut the record in half and the next round would fall back to guessing — which is exactly
// the failure this record exists to end. Pure, because it lived in `upsertSummary` where no test could reach it
// and both mutations (drop the record, trim it with the body) stayed green.
// Redact a summary body that may already CARRY a record — the degrade path builds one that way, because
// `summaryWithNote` pulls the record out of the previous comment and re-appends it inside the body it returns.
// Running `redact` across that assembled string re-opens the very hazard per-field redaction closed: a
// dangling `-----BEGIN … PRIVATE KEY-----` in one entry's text and a dangling `-----END …-----` in another's
// both survive per-field redaction, and the unbounded pattern then matches ACROSS the concatenation and eats
// every entry between them. Measured on this path: three entries in, one out. The blob's fields were already
// redacted when they were written, so it is left exactly as it is and only the prose around it is redacted.
export function redactBody(body) {
  const text = String(body ?? '');
  const start = text.indexOf(STATE_MARKER);
  if (start === -1) return redact(text);
  const end = text.indexOf(' -->', start + STATE_MARKER.length);
  if (end === -1) return redact(text);
  const blob = text.slice(start, end + ' -->'.length);
  return `${redact(text.slice(0, start))}${blob}${redact(text.slice(end + ' -->'.length))}`;
}

// Redaction applied to a record ENTRY at a time, so no pattern can span two of them. `redact` is otherwise
// unchanged; this only decides what it is pointed at.
function redactState(state) {
  const out = {};
  for (const [fp, r] of Object.entries(state?.findings || {})) {
    out[fp] = { ...r, file: redact(String(r.file ?? '')), text: redact(String(r.text ?? '')) };
  }
  return { commit: redact(String(state?.commit ?? '')), findings: out };
}

export function summaryBodyWithState(redactedBody, state = null) {
  // The record is encoded FIRST, so the summary is bounded by what the record actually costs rather than by a
  // fixed 20 KB reservation: a round with three findings was spending 20 KB of a human's summary on a record of a
  // few hundred bytes, and a round with none was spending it on nothing at all.
  // Redacted per FIELD, before the blob is assembled. Every pattern in `redact` is bounded except the private
  // key block, whose `[\s\S]*?` will happily start in one entry's text and end in another's — deleting every
  // entry between them and splicing the survivors' fields together. Measured: three findings in, two out, one
  // thread id destroyed, and a different arrangement makes the JSON unparseable, which is total loss of the
  // record. A field can no longer reach across its neighbours.
  const encoded = state ? encodeState(redactState(state)) : '';
  const room = GITHUB_COMMENT_LIMIT - encoded.length - MAX_STATE_MARGIN;
  const bounded = boundedSummaryBody(redactedBody, room);
  return encoded ? `${bounded}\n${encoded}` : bounded;
}

// Build the summary body for a degrade note: keep whatever review is already there (upsertSummary overwrites, and
// a transient fatal must not replace a complete review a human may be reading) and REPLACE a previous note of the
// same kind rather than stacking one. Pure, so the replace rule is unit-tested.
export function summaryWithNote(previousBody, note, heading) {
  // The record rides in this comment, and a degrade note rewrites the comment. Pull it out first and re-append it
  // after the trim, or a failed round would erase the record and send the NEXT round back to guessing — which is
  // the same failure the record exists to end, arriving by a different door.
  const carriedRecord = (String(previousBody || '').match(/<!-- bp-ai-review-state:[\s\S]*? -->/) || [])[0] || '';
  // The marker leads the note, so splitting on it drops the previous note entirely. With the marker trailing it,
  // the split kept all of the note's text and dropped only the marker, so a paragraph accumulated on every failing
  // push — and twice per run, since runReview() explains a fatal and the top-level handler explains the same one again.
  const kept = String(previousBody || '')
    .split(MARKER_FAILURE_NOTE)[0]
    .replace(MARKER_SUMMARY, '')
    .replace(carriedRecord, '')
    .replace(/\n*---\s*$/, '')
    .trimEnd();
  const body = `${MARKER_FAILURE_NOTE}\n\n${note}`;
  if (!kept) return [heading, '', body, '', MARKER_SUMMARY, carriedRecord].filter(Boolean).join('\n');
  // Room is reserved for the note and the markers before the old review is trimmed. Trimming the whole thing
  // afterwards would cut from the end, which is where the note lives: the run would then look like a stale review
  // with a "trimmed" line and no explanation at all — the invisible failure this function exists to prevent.
  // The separators count too. Reserving only body + record + marker + margin left this function returning
  // ~11 characters more than `summaryBodyWithState` allows when it re-bounds the result, so on a previous
  // summary long enough for the slice to bite, the trim took the record's own ` -->` terminator with it and
  // `decodeState` returned null — losing the record this path re-appends it specifically to protect.
  // Every separator this function emits, including the `\n` that precedes the closers when a repair is needed.
  // Leaving that one out made the worst case exactly one character over what `summaryBodyWithState` re-bounds
  // to — and its trim cuts at a line boundary, where the last line is the record, so the degrade path would
  // lose the record it re-appends specifically to protect. Reachable at equality, not just in theory.
  const SEPARATORS = '\n\n---\n\n'.length + '\n\n'.length + '\n'.length + '\n'.length;
  // And the cut is repaired, for the same reason `boundedSummaryBody` repairs its own: `renderSummary` puts
  // every unpostable finding inside a `<details>` block, so on a summary long enough for this slice to bite the
  // cut lands INSIDE that element and the "did not complete" note renders collapsed — invisible, in the one
  // path that exists to make a failure visible. Fixed twenty lines above and not here, which is how a fix in
  // one branch fails to be a fix in the other; both call the same repair now.
  let room = Math.max(0, GITHUB_COMMENT_LIMIT - body.length - carriedRecord.length - MARKER_SUMMARY.length - SEPARATORS - MAX_STATE_MARGIN);
  let cut = kept.slice(0, room);
  let closers = closeUnbalancedDetails(cut);
  for (let i = 0; i < 4 && closers.length; i++) {
    const next = kept.slice(0, Math.max(0, room - closers.length));
    const nextClosers = closeUnbalancedDetails(next);
    if (next.length + nextClosers.length <= room) { cut = next; closers = nextClosers; break; }
    room = Math.max(0, room - closers.length);
    cut = next;
    closers = nextClosers;
  }
  return [`${cut}${closers ? `\n${closers}` : ''}\n\n---\n\n${body}\n\n${MARKER_SUMMARY}`, carriedRecord].filter(Boolean).join('\n');
}

// Both degrade routes use this: the deadline route is the likely one on a large PR.
export async function appendNoteToSummary(note, heading) {
  // The flag is checked HERE rather than in each caller, because one caller forgot: `--setup-failed` posted a
  // real comment under `DRY_RUN=1`, against a README that promises every write path sits behind the flag. Every
  // note-writer inherits it now, and the note still reaches the log, which is the whole point of a dry run.
  if (DRY_RUN()) {
    console.log(`[dry-run] would append to the summary under "${heading}":\n${note}`);
    return;
  }
  try {
    // The read is handed on, not repeated: `upsertSummary` needs the same listing to find the comment it updates,
    // and paginating it twice was the thing the main path stopped doing — up to 20 GETs with their own ladders,
    // and two reads that can disagree about whether a summary exists, with the later one silently deciding
    // whether a SECOND one is posted. It matters most in `--setup-failed`, where both reads share a 90-second
    // network budget and this note is the only output that path has.
    const listing = { ...(await listIssueComments(PR_NUMBER())), readAt: Date.now() };
    const previous = listing.comments.find((c) => isHarnessComment(c.user?.login) && (c.body || '').includes(MARKER_SUMMARY));
    await upsertSummary(summaryWithNote(previous?.body || '', note, heading), null, { listing });
    return true;
  } catch (e) {
    // The run log carries the reason for the ORIGINAL failure — that is logged before this is ever called — but
    // it did not carry this one: why the note could not be posted. In `--setup-failed` that is the whole output
    // of the mode, so a refused write (a stale token's 403, a 422, the 90-second budget running out) printed the
    // setup reason, wrote nothing to the pull request, and exited 0 — a green step, no comment, and nothing
    // anywhere naming the GitHub error.
    console.warn(`Could not append the note to the summary (${redact(e.message || String(e))}); the reason above is in this log only`);
    return false;
  }
}

// Tell the WORKFLOW that the pull request already carries an explanation. The workflow's fallback note exists for
// the one failure the harness cannot report on its own — the step being killed (its timeout, an OOM) rather than
// failing on its own terms, where none of the handlers below ever run — and that step must not fire when the
// harness did explain itself, because both notes share a heading and the second would replace the first, trading
// the actual error for "the step ended without writing a summary". Only a note that LANDED counts. A killed step
// writes nothing here, so the fallback fires, which is the direction the failure has to fall in.
export function recordExplainedOnPr() {
  const out = process.env.GITHUB_OUTPUT;
  if (!out) return;
  try {
    appendFileSync(out, 'explained=true\n');
  } catch (e) {
    console.warn(`could not record that the PR was told (${redact(e.message)}); the workflow may add a second note`);
  }
}

// Say why on the PR before failing the check — the run log alone is easy to miss. Returns the error for rethrow.
// A summary write that fails is not a cosmetic loss, and it used to be logged and forgiven. The summary is the
// round's only durable output: it is where a finding that could not be posted inline lives, and where the state
// record lives, so a round whose summary never landed has put nothing on the pull request and remembers nothing —
// and it did that while exiting 0, which is the invisible failure this file is organised around. Found by the
// conservation fuzzer once it started failing the comment writes as well: three findings, reported, nowhere, green.
// Throwing hands it to the top-level handler, which tries to say so on the PR and then exits 1 — a red check is
// the one signal left when the harness cannot write to the PR at all.
export function summaryWriteFailed(e) {
  throw new Error(`Could not post the summary comment, so this round produced no visible output: ${redact(e.message)}`, { cause: e });
}

// Exported for the test that pins the rule inside it: only a note that LANDED may tell the workflow the pull
// request has been told. Nothing else reaches this function — the top-level handler is the only caller, and that
// runs when the file is executed rather than imported.
export async function explainFailure(err) {
  // Bounded: rest()/graphql() embed the whole upstream response in their message, and this note is appended to
  // the previous summary — an unbounded body would push the comment past GitHub's 65 536-char limit, the post
  // would fail, and the catch below would swallow exactly the failure this function exists to surface.
  const note = `> ⚠️ **A run did not complete:** the reviewer failed before producing a result: ${boundedDump(err.message || String(err), 2000)}`;
  if (await appendNoteToSummary(note, '## ⚠️ Claude PR Review — did not run')) recordExplainedOnPr();
  return err;
}

// `state` is not optional in spirit: this call REPLACES the summary comment, and the state record lives inside
// that comment, so passing nothing erases the harness's memory of every earlier round. Pass the round's own new
// record, or the one the round read (unchanged), or — as `appendNoteToSummary` does — a body that already carries
// the record it pulled out and re-appended.
export async function upsertSummary(rawBody, state = null, { mergeExistingRecord = false, listing = null } = {}) {
  // The read this write depends on can fail on its own, and it used to take the whole write with it: the round
  // then said NOTHING — no summary, no findings, no note — which on a round that also could not read the
  // threads (so posted nothing inline) meant the entire round's output vanished. Found by the conservation
  // fuzzer once it started failing the thread listing as well. A comment that may duplicate an existing one is
  // visible and fixable; silence is neither, so the write goes ahead without an id to update.
  //
  // `listing` is the read runReview() already did for the state record. Paginating the same comments twice per round
  // costs up to 20 GETs with their own ladders inside the job budget, and the two reads could disagree about
  // whether a summary exists at all — the later one deciding, silently, whether a SECOND one gets posted. What
  // this function needs from it is a comment id, which does not change while the round runs; if the comment is
  // gone by the time we write, the update below says so with a 404 and takes the fresh-read path.
  let comments = listing?.comments || [];
  let truncated = listing?.truncated || false;
  if (!listing) {
    try {
      ({ comments, truncated } = await listIssueComments(PR_NUMBER()));
    } catch (e) {
      truncated = true;
      console.warn(`Could not read this PR's comments before writing the summary (${redact(e.message)}); posting rather than staying silent`);
    }
  }
  let existing = comments.find((c) => isHarnessComment(c.user?.login) && (c.body || '').includes(MARKER_SUMMARY));
  // A summary CREATED mid-round is the case the cached listing cannot see: it was read up to seventeen minutes
  // ago, and the 404 branch below only covers one that was DELETED since. Posting then means a second summary —
  // two state records, which this function calls its worst outcome — and it is reachable through the same
  // `cancel-in-progress` window `planRound` documents, where a superseded run posts after this round listed.
  //
  // Gated on the listing's AGE, not on its presence: the note path reads and writes seconds apart, so re-reading
  // there buys nothing and costs a GET out of a 90-second budget where the note is the only output. A listing
  // with no `readAt` counts as stale, because the question this is asking is "could something have happened
  // since?" and "I do not know when this was read" is not a no. One GET, on the round that would duplicate.
  if (!existing && listing && Date.now() - (listing.readAt ?? 0) > STALE_LISTING_MS) {
    try {
      ({ comments, truncated } = await listIssueComments(PR_NUMBER()));
      existing = comments.find((c) => isHarnessComment(c.user?.login) && (c.body || '').includes(MARKER_SUMMARY));
    } catch (e) {
      console.warn(`Could not re-check for a summary posted during this round (${redact(e.message)}); posting rather than staying silent`);
    }
  }
  // Posting a SECOND summary is the one thing this function must not do quietly: the record lives in the
  // summary, so two of them means two memories, and the next round reads whichever it finds first. If the
  // listing stopped early and no summary was in what we saw, say so loudly — the comment still gets posted,
  // because a round with no summary at all is the worse failure, but the log names the reason.
  if (!existing && truncated) {
    console.warn('The comment listing was truncated and no summary was found in it; posting a new one, which may duplicate an existing summary');
  }
  // `mergeExistingRecord` is set when this round could not READ the record: this write would otherwise replace
  // the comment it lives in with a record built from nothing. The comment is in hand here (the upsert has to
  // find it anyway), so what it still holds is merged UNDER this round's entries — this round wins per
  // fingerprint, and everything it never learned about survives instead of being deleted.
  const carried = mergeExistingRecord ? decodeState(existing?.body || '') : null;
  const merged = carried
    ? {
        commit: state?.commit || carried.commit,
        findings: Object.fromEntries(
          [...new Set([...Object.keys(carried.findings), ...Object.keys(state?.findings || {})])].map((fp) => {
            const before = carried.findings[fp];
            const now = state?.findings?.[fp];
            if (!now) return [fp, before];
            // Per field, not per entry: this round could not read the record, so an entry it rebuilt from the
            // comment bodies alone may hold `id: null` for a thread whose body a maintainer has edited. A
            // thread id we knew is knowledge; a null is the absence of it, and must not overwrite the other.
            return [fp, { ...before, ...now, id: now.id || before?.id || null }];
          }),
        ),
      }
    : state;
  if (carried) console.warn(`Merging this round's record into the ${Object.keys(carried.findings).length} entry/entries already in the summary`);
  const body = summaryBodyWithState(redactBody(rawBody), merged);
  if (!existing) return postIssueComment(PR_NUMBER(), body);
  try {
    return await updateIssueComment(existing.id, body);
  } catch (e) {
    // Only when the comment is GONE. Any other refusal has to stay a failure: posting a new summary over a
    // transient 500 is how a PR ends up with two records, and the caller turns a failed write into a red check
    // precisely so nobody has to guess. A deleted summary is the one case where posting is the right answer —
    // and it is reachable now that the id can come from a listing read at the start of the round.
    if (e?.status !== 404 && e?.status !== 410) throw e;
    console.warn(`The summary comment (${existing.id}) is gone; posting a new one`);
    return postIssueComment(PR_NUMBER(), body);
  }
}

// `--setup-failed <reason>`: the workflow calls this when a step BEFORE the review failed (the install, or the
// harness's own tests). Those run outside runReview(), so nothing would otherwise reach the PR and the check would go
// red with no comment — the invisible failure the rest of this file exists to avoid. Note only: no agent, no
// review, no reconciliation, and it needs nothing but a token and a PR number.
export async function reportSetupFailure(reason) {
  // Logged FIRST. `appendNoteToSummary` swallows a failed write ("the run log still carries the reason"), and
  // this function was the one place where that was false: it never logged anything, so a --setup-failed run
  // that could not reach GitHub printed nothing, wrote nothing and exited 0 — the invisible failure this mode
  // exists to prevent, in the mode built to prevent it.
  console.warn(`The reviewer did not run: ${redact(String(reason || 'a step before the review failed'))}`);
  const note = `> ⚠️ **The reviewer did not run:** ${boundedDump(reason || 'a step before the review failed', 400)}${RUN_URL() ? ` See the [run log](${RUN_URL()}).` : ''}`;
  // This note IS the mode: there is no summary, no findings, nothing else it produces. So whether it landed is
  // worth a line of its own — a reader of the log should not have to infer it from the absence of a comment.
  // No `recordExplainedOnPr()` here, and the absence is deliberate: `explained` is read as
  // `steps.review.outputs.explained`, and this mode runs in the NOTE steps, never in the review step — so writing
  // it from here sets an output on a step nothing consults. It looked like part of the gate and was not.
  if (!(await appendNoteToSummary(note, '## ⚠️ Claude PR Review — did not run'))) {
    console.warn('The pull request was NOT told that the reviewer did not run; this log is the only record');
  }
}

// All `--setup-failed` has to do is read the summary comment and write it back.
export const SETUP_NOTE_BUDGET_MS = 90_000;
