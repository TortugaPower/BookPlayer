// Which finding is which, across pushes: fingerprints, the `same_as` protocol, the hidden state record in the
// summary, the markers that make a thread recognisably ours, and `planRound`, the pure decision of what this
// round does with the threads already on the PR. Nothing here talks to GitHub or to the model.

import { createHash } from 'node:crypto';
import { boundedDump, escapeAttr, escapePrText } from './sandbox.mjs';

export const MARKER_SUMMARY = '<!-- bp-ai-review-summary -->';

// Markers are public strings; only honour them on comments this harness authored (posted with GITHUB_TOKEN).
// REST reports the Actions bot as `github-actions[bot]`, GraphQL as `github-actions`.
const HARNESS_LOGINS = new Set(['github-actions[bot]', 'github-actions']);

export const isHarnessComment = (login) => HARNESS_LOGINS.has(login);

// Ceiling on inline comments per run; anything beyond goes into the summary instead of burying the PR.
export const MAX_INLINE = 25;

// Left as a reply when the harness (not a human) resolves a thread, so a finding that comes back can be
// reopened instead of silently counted as "carried over" on a resolved thread.
const MARKER_AUTO_RESOLVED = '<!-- bp-ai-review-auto-resolved -->';

export const MARKER_VERIFIED = '<!-- bp-ai-review-verified -->';

export const MARKER_HUMAN_ACCEPTED = '<!-- bp-ai-review-accepted-by-human -->';

// A note on a thread that stays OPEN. Deliberately not a resolution marker: if a human later resolves the thread
// themselves, that decision must stand rather than being reopened as if the harness had closed it.
export const MARKER_VERIFY_NOTE = '<!-- bp-ai-review-verify-note -->';

export const MARKER_FAILURE_NOTE = '<!-- bp-ai-review-failed -->';

// Resolutions this harness made: if the fresh review reports the finding again, the thread reopens once. That
// includes an "accepted" close, because the acceptance is the model's reading of a maintainer's reply — the harness
// only knows a maintainer replied, not that they dismissed it. If the human resolves it again themselves, their
// resolution carries no marker and is respected from then on.
export const HARNESS_RESOLVED_MARKERS = [MARKER_AUTO_RESOLVED, MARKER_VERIFIED, MARKER_HUMAN_ACCEPTED];

// Posted when the verification pass judged this thread's finding to be the same issue as one reported on this
// push — a finding whose line moved, or two threads that ended up tracking one issue. The harness confirms the
// finding it names actually landed before closing anything on it, so the sentence is always true when a reader
// sees it. The line is filled in from the verdict.
export const duplicateNote = (line, evidence) =>
  `The same issue is reported on this push at line ${line}, so this thread is being closed in favour of that comment.` +
  `${evidence ? ` ${evidence}` : ''} ${MARKER_AUTO_RESOLVED}`;

// (The note earlier versions posted when a finding simply went unreported is gone; only its MARKER_AUTO_RESOLVED
// survives, in HARNESS_RESOLVED_MARKERS, so threads those versions closed are still recognised as ours and
// reopen on a re-report. Nothing closes a thread on silence any more.)
// Posted when we reopen, so the auto-resolve marker is no longer the last comment: if a human then resolves
// the thread themselves, that decision is respected on later runs.
export const REOPENED_NOTE = 'Reported again in the latest run — reopened. <!-- bp-ai-review-reopened -->';

const MARKER_REWORDED = '<!-- bp-ai-review-reworded -->';

const FP_REGEX = /<!-- bp-ai-review-fp:([a-f0-9]+) -->/;

// The fingerprint a thread carries. The record answers when it has an entry for that thread; the marker in the
// comment body is the FALLBACK, for a PR opened before the record existed and for a round where the record could
// not be read. Both paths live here rather than in each consumer: three of them drifted apart before this, and an
// end-to-end round caught two of them still parsing bodies after the others had moved.
export function fingerprintOfThread(thread, priorState = null) {
  const records = Object.entries(priorState?.findings || {});
  for (const [fp, record] of records) {
    if (record?.id && record.id === thread.id) return fp;
  }
  // Then the comment id, which the record has for a finding posted in the round that wrote it — a round cannot
  // know the thread id of a comment it is creating, so without this the first round after a post falls through to
  // the marker in the body, and a maintainer who edits that body takes the identity with it.
  for (const [fp, record] of records) {
    if (record?.commentId && thread.firstCommentId && record.commentId === thread.firstCommentId) return fp;
  }
  return (FP_REGEX.exec(thread.firstCommentBody || '') || [])[1];
}

// Fingerprint identifies "the same issue at the same spot" across runs.
// Intentionally EXCLUDES the comment text so a re-wording doesn't create a duplicate.
// Location, and a `salt` only when one is passed. See `keyFindings`: the salt is what a SECOND finding at an
// occupied location is keyed by, so two findings that share a place do not share an identity.
export function fingerprint(f) {
  const salt = f.salt ? `|${f.salt}` : '';
  return createHash('sha1').update(`${f.file}|${f.line}|${f.severity}${salt}`).digest('hex').slice(0, 12);
}

export function severityEmoji(s) {
  return s === 'error' ? '🔴' : s === 'warn' ? '🟡' : '🔵';
}

// ---------------------------------------------------------------------------------------------------------------
// The harness's own record of what it did.
//
// Everything about a previous round used to be re-derived from the PR's rendered comments: fingerprints pulled out
// of markdown with a regex, our own past actions inferred from HTML-comment markers, severity re-parsed from an
// emoji prefix, "did we close this" decided by marker archaeology over a comment window that silently truncates,
// "who resolved this" unknowable in principle. That is a lossy projection of the harness's history, and five
// review rounds produced the same class of defect from it again and again — two threads for one finding, an
// anchor that had to be "open or reopening", a close indistinguishable from a human's.
//
// So the harness writes its history down. One hidden blob in its own summary comment, per finding: the
// fingerprint, the thread it lives on, what was done last round, and at which commit. Reconciliation then reads
// its own record instead of parsing its own output. What must still come from the API is what the API actually
// knows: whether a thread is resolved, and whether a human has replied.
//
// The record is advisory: a PR opened before this landed has none, and a body can be edited, so every consumer
// falls back to the marker-derived answer when the record is absent. It is trusted only from a comment this
// harness authored, which is the same rule the markers already have.
// ---------------------------------------------------------------------------------------------------------------

export const STATE_MARKER = '<!-- bp-ai-review-state:';

const STATE_VERSION = 1;

// Bounded twice, by count and by bytes: 200 records of the longest plausible text came to 81 KB, past GitHub's
// 65 536-character comment limit — the record would have destroyed the comment it rides in. 60 is well beyond the
// inline cap, and the byte budget is the backstop that does not depend on my arithmetic staying right.
// One comment carries both the summary a human reads and the record the next round reads, so their budgets are
// derived from GitHub's single limit rather than chosen separately. They were not: 60 000 for the summary plus
// 20 000 for the record is 80 000, and the comment would have been REJECTED — the earlier test passed only
// because its record was a few hundred bytes.
export const GITHUB_COMMENT_LIMIT = 65_536;

export const MAX_STATE_BYTES = 20_000;

export const MAX_STATE_MARGIN = 1_000; // the summary's own trim notice, the markers, and the newline between the halves

// A count cap and a byte cap, and on real data the BYTES bind first: 60 entries with real file paths and real
// GraphQL node ids measure ~20 KB, so the effective ceiling is nearer 48 entries. Both are enforced, and a trim
// says so in the log — it used to be silent, and what it drops is the tail: the carried entries, which is the
// part nothing else can reconstruct.
const MAX_STATE_RECORDS = 60;

const MAX_STATE_TEXT = 160;

export function encodeState(state) {
  let records = Object.entries(state.findings || {}).slice(0, MAX_STATE_RECORDS);
  const wrap = (entries) => {
    const payload = { v: STATE_VERSION, commit: state.commit || '', findings: Object.fromEntries(entries) };
    // The blob is data, not prose. JSON.stringify escapes nothing that would close an HTML comment early, but a
    // finding's own text can contain `-->`, so that one sequence is neutralised and restored on read.
    // `-->` would close the HTML comment early, so it is escaped — and ONLY that sequence, one character at a
    // time, so the decoder can put back exactly what was taken. `/--+>/ -> '--&gt;'` was not symmetric: it ate
    // the extra dashes of `--->`, and it also rewrote a literal `--&gt;` a maintainer had typed. That text
    // feeds nothing but a human's eyes now, but a record that does not round-trip is a record that lies.
    return `${STATE_MARKER}${JSON.stringify(payload).split('-->').join('--\\u003e')} -->`;
  };
  // Records are already severity-first, so dropping from the end drops the least consequential.
  let encoded = wrap(records);
  const before = records.length;
  while (encoded.length > MAX_STATE_BYTES && records.length) {
    records = records.slice(0, -1);
    encoded = wrap(records);
  }
  const dropped = Object.keys(state.findings || {}).length - records.length;
  // Said out loud, because the entries this drops are the ones the next round cannot rebuild: a carried
  // identity or a remembered close simply stops existing, and nothing else in the run mentions it.
  if (dropped > 0) {
    console.warn(
      `State record trimmed: ${records.length} of ${Object.keys(state.findings || {}).length} entries kept ` +
        `(${before - records.length} dropped for the ${MAX_STATE_BYTES}-byte budget, the rest for the ${MAX_STATE_RECORDS}-entry cap)`,
    );
  }
  return encoded;
}

export function decodeState(body) {
  const text = String(body || '');
  const start = text.indexOf(STATE_MARKER);
  if (start === -1) return null;
  const end = text.indexOf(' -->', start + STATE_MARKER.length);
  if (end === -1) return null;
  try {
    const parsed = JSON.parse(text.slice(start + STATE_MARKER.length, end));
    if (parsed?.v !== STATE_VERSION || !parsed.findings || typeof parsed.findings !== 'object') return null;
    return { commit: String(parsed.commit || ''), findings: parsed.findings };
  } catch {
    return null; // an unreadable record is no record: every consumer falls back to the markers
  }
}

// Which thread carries which finding, from the threads as fetched — the one place a fingerprint is still read out
// of a comment body, and only to seed the record that replaces doing so.
export function threadIdByFp(threads = [], priorState = null) {
  const map = new Map();
  const ours = threads.filter((t) => isHarnessComment(t.firstCommentAuthor));
  const ids = new Set(ours.map((t) => t.id));
  // What the last record said, for as long as that thread still exists: a body can be edited, and an edited body
  // used to lose the thread — the next record then carried `id: null` and the round after it was blind again.
  for (const [fp, record] of Object.entries(priorState?.findings || {})) {
    if (record?.id && ids.has(record.id)) map.set(fp, record.id);
  }
  for (const t of ours) {
    const fp = fingerprintOfThread(t, priorState);
    if (fp && !map.has(fp)) map.set(fp, t.id);
  }
  return map;
}

// What happened to each finding this round, in the record's vocabulary. Fingerprint-keyed, because that is how
// the record is keyed and how the next round looks a thread up.
// `unpostableFps` are the keys reconcile actually used, not a hash re-derived from the finding. Re-deriving was
// wrong the moment a finding could be keyed with a salt (a collision at one location) or by the agent's own
// `same_as`: the recomputed hash then matched nothing, so the finding was recorded as `posted` when it could not
// be posted, and the `unpostable` entry landed under a key no round would ever look up.
export function actionByFp({ unpostableFps = [], currentByFp = new Map() } = {}) {
  const actions = new Map();
  for (const [fp] of currentByFp) actions.set(fp, 'posted');
  for (const fp of unpostableFps) actions.set(fp, 'unpostable');
  return actions;
}

// The threads this round CLOSED, as record entries. Without these the record never carries a close at all: a
// closed thread's finding is by definition absent from `currentByFp`, so `buildState` never saw it, no record ever
// held an action in HARNESS_CLOSE_ACTIONS, `harnessClosedByRecord` always returned null, and the marker
// archaeology the record was built to replace was still what ran in production. The tests passed only because
// they hand-wrote `action: 'resolved'`.
export function closedRecords({ identities = new Map(), threads = [], verifiedClosedIds = new Set(), duplicateClosedIds = new Set() } = {}) {
  const entries = [];
  // The threads by id, because the callers hold only ids: `thread.line ?? thread.originalLine ?? 0` was reading a
  // synthetic `{ id, line: 0 }`, so it could not return anything but 0 while advertising an anchor. Nothing reads
  // a closed entry's line today — `openFindings` takes the anchor from the live thread — and these are the
  // entries `carriedRecords` keeps longest, so a future reader would have got 0 for exactly them.
  const byId = new Map(threads.map((t) => [t.id, t]));
  const add = (id, action) => {
    const thread = byId.get(id) || { id, line: null, originalLine: null };
    const identity = identities.get(thread.id);
    if (!identity?.fp) return; // no fingerprint, nothing the next round could look up
    entries.push([
      identity.fp,
      {
        id: thread.id,
        file: identity.path,
        line: thread.line ?? thread.originalLine ?? 0,
        severity: identity.severity,
        // Bounded here as well as in `identities`: this function had no bound of its own, so it inherited whatever
        // the identity happened to hold — 25 closes at ~2 KB each once crowded every current finding out of the
        // record. A bound that exists by coupling is not a bound.
        text: String(identity.text || '').slice(0, MAX_STATE_TEXT),
        action,
        // When we closed it. A record can be rolled back by an overlapping run's later write, so a close that is
        // no longer our last word on the thread must stop counting — see harnessClosedByRecord.
        at: new Date().toISOString(),
      },
    ]);
  };
  // Both sets hold threads whose resolve LANDED — the callers add an id only after `io.resolve` returned — so
  // no record here claims a close that failed.
  for (const id of verifiedClosedIds) add(id, 'resolved');
  for (const id of duplicateClosedIds) add(id, 'duplicate');
  return entries;
}

// The record the last round left, from this harness's own summary comment. Absent on a PR opened before this
// landed, and on the first round of any PR, so every consumer treats it as advisory.
export async function readPriorState(comments) {
  const summary = (comments || []).find((c) => isHarnessComment(c.user?.login) && (c.body || '').includes(MARKER_SUMMARY));
  return decodeState(summary?.body || '');
}

// The record this round leaves behind, built from what reconcile and the verification pass actually did.
// What the next round needs to remember that this round did not decide: an earlier close, for as long as its
// thread is still resolved, and the identity of every still-open thread this round did not re-report. Without this the record
// only ever described the findings of the round that wrote it, so one quiet round dropped a live thread out of
// it and identity fell back to the marker in the comment body — which is exactly the thing the record exists to
// stop depending on (a maintainer edits the body, GitHub renders it, the marker is gone, and the thread becomes
// unrecognisable). Found by chaining three real rounds together instead of hand-writing round N's record.
export function carriedRecords({ identities = new Map(), threads = [], currentByFp = new Map(), closed = [], priorState = null, commit = '' } = {}) {
  const closedFps = new Set(closed.map(([fp]) => fp));
  const byId = new Map(threads.map((t) => [t.id, t]));
  // FIRST: closes this harness made in an EARLIER round, for as long as the thread is still there and still
  // resolved. `closed` only holds the closes made THIS round, so a close was remembered for exactly one round —
  // and then `harnessClosedByRecord` had nothing, falling back to the marker in the reply we posted. When that
  // reply had failed (a resolve works, its note does not), the thread read as a maintainer's own decision and the
  // finding was dismissed for good the next time it returned. These come before the open-thread identities
  // below: a lost close silently drops a finding, where a lost identity only posts a second comment.
  const out = [];
  for (const [fp, record] of Object.entries(priorState?.findings || {})) {
    if (!record?.id || !HARNESS_CLOSE_ACTIONS.has(record.action)) continue;
    if (currentByFp.has(fp) || closedFps.has(fp)) continue; // reported again, or closed again this round
    const t = byId.get(record.id);
    if (!t || !t.isResolved) continue; // gone, or open again: nothing to remember
    out.push([fp, record]); // unchanged, `at` included — that is when we closed it
  }
  // THEN: the identity of every thread that is still open and that this round did not re-report.
  for (const [id, identity] of identities) {
    const t = byId.get(id);
    // Resolved threads are handled above: a closed thread's fingerprint only matters if we closed it. An open
    // one is the harness's outstanding work.
    if (!t || t.isResolved) continue;
    if (!identity.fp || currentByFp.has(identity.fp) || closedFps.has(identity.fp)) continue;
    out.push([identity.fp, {
      id,
      file: identity.path,
      line: threadAnchor(t).line ?? t.line ?? null,
      severity: identity.severity,
      // Bounded here as well as in `identities`: a bound that exists only by coupling is not a bound (the
      // same lesson `closedRecords` learned when 25 closes at ~2 KB each crowded out every current finding).
      text: String(identity.text || '').slice(0, MAX_STATE_TEXT),
      // Never a close action: `harnessClosedByRecord` must not read this as "we closed it", because we did not.
      action: 'open',
      commit: String(commit || '').slice(0, 40),
    }]);
  }
  return out;
}

export function buildState({ commit, currentByFp, threadIdByFp = new Map(), actions = new Map(), closed = [], carried = [], commentIdByFp = new Map(), priorState = null }) {
  const findings = {};
  // Closes go in first, so a thread this round closed is in the record even when the round also reported many
  // new findings and the cap trims.
  for (const [fp, record] of closed) findings[fp] = { ...record, commit: String(commit || '').slice(0, 40) };
  // Bounded here, not only at the encoder, so nothing downstream carries an unbounded record — and ordered
  // severity-first, so a truncated one keeps the findings that matter rather than whichever came first.
  const ranked = [...currentByFp].sort(([, a], [, b]) => (SEVERITY_RANK[a.severity] ?? 9) - (SEVERITY_RANK[b.severity] ?? 9));
  for (const [fp, f] of ranked.slice(0, Math.max(0, MAX_STATE_RECORDS - Object.keys(findings).length))) {
    // The comment this round created for it, or the one an earlier round recorded. A thread id is what the next
    // round prefers; this is the fallback while there is none, because a round cannot know the thread id of a
    // comment it is creating — the listing that would name it was read before the post. Written only when there
    // IS one: `"commentId":null` on sixty entries is a kilobyte of the record's 20 KB budget spent saying nothing.
    const commentId = commentIdByFp.get(fp) || priorState?.findings?.[fp]?.commentId || null;
    findings[fp] = {
      id: threadIdByFp.get(fp) || null,
      ...(commentId ? { commentId } : {}),
      file: f.file,
      line: f.line,
      severity: f.severity,
      text: String(f.comment || '').slice(0, MAX_STATE_TEXT),
      action: actions.get(fp) || 'posted',
      commit: String(commit || '').slice(0, 40),
    };
  }
  // Then the open threads nobody mentioned this round, last: a close is knowledge nothing else holds, and a
  // finding this round reported is the round's own subject, but a carried entry only keeps an identity that the
  // comment body can still supply as a fallback. Under the same cap, so a record cannot grow without bound as a
  // long-lived PR accumulates threads.
  for (const [fp, record] of carried) {
    if (Object.keys(findings).length >= MAX_STATE_RECORDS) break;
    if (!findings[fp]) findings[fp] = { ...record, commit: String(commit || '').slice(0, 40) };
  }
  return { commit: String(commit || '').slice(0, 40), findings };
}

// A function, not an object: these constants are declared further down, and a `const` object built here would be
// evaluated at import time — before them — which throws on the temporal dead zone the moment anything imports
// this module.
export const CAPS_FOR_TEST = () => ({ MAX_VERIFY_THREADS, MAX_REPORTED_PER_FILE, MAX_OPEN_FINDINGS_SHOWN });

const MAX_VERIFY_THREADS = 20;

// How many of THIS push's findings are quoted alongside a thread being judged, so a `duplicate` verdict has
// something concrete to name. Separate from the thread cap above on purpose: they were one constant, and the two
// mean different things.
export const MAX_REPORTED_PER_FILE = 20;

// How many still-open findings the REVIEW prompt offers the agent to claim with `same_as`. Its own constant for
// the same reason as the one above: this bounds what the agent can state an identity for, and anything past the
// cut falls back to the fingerprint heuristic — the inference the claim protocol exists to replace. That is a
// different question from how many threads a round can afford to VERIFY, which is a budget decision.
const MAX_OPEN_FINDINGS_SHOWN = 20;

export const MAX_VERIFY_CHARS = 1200; // per finding, and per reply

const MAINTAINER_ASSOCIATIONS = new Set(['OWNER', 'MEMBER', 'COLLABORATOR']);

const SEVERITY_RE = /\*\*(ERROR|WARN|INFO)\*\*/;

// Does this body still look like something this harness rendered? Only then is its text the finding's text: a
// body edited past recognition says whatever the editor wanted, and the record is the only source left.
const bodyLooksOurs = (body) => SEVERITY_RE.test(String(body || '')) || FP_REGEX.test(String(body || ''));

export function findingSeverity(body) {
  const m = SEVERITY_RE.exec(String(body || ''));
  return m ? m[1].toLowerCase() : '';
}

// `line` is null on an outdated thread; the fallback anchor is from an earlier commit and is labelled as such.
// One wording for both prompts that show an anchor: the verifier's and the review's open-findings list. The
// review prompt used to render a stale line bare, so the two prompts disagreed about a fact they both had — and a
// stale anchor presented as current is the one thing that can make a correct `same_as` claim look wrong.
export const STALE_ANCHOR_ATTR = 'anchor="stale: from the commit the finding was raised on — the code may have moved"';

export function threadAnchor(t) {
  if (t.line != null) return { line: t.line, stale: false };
  return { line: t.originalLine ?? null, stale: true };
}

export function stripHarnessMarkup(body) {
  return body.replace(/<!--[\s\S]*?-->/g, '').replace(/^[^\s]*\s*\*\*(ERROR|WARN|INFO)\*\*\s*—\s*/i, '').trim();
}

// A reply that can close a thread must come from someone other than the harness and other than the PR author:
// on a same-repo PR the author's own association is usually OWNER, so "a maintainer accepted it" would otherwise
// include the author accepting their own finding.
export function isMaintainerReply(c, prAuthor = '') {
  if (isHarnessComment(c.author)) return false;
  if (prAuthor && c.author === prAuthor) return false;
  return MAINTAINER_ASSOCIATIONS.has(c.association);
}

// What this round does with the threads already on the PR, as a pure decision. Lifted out so the composition can
// be asserted directly — `runReview()` IS reachable from a test now, through the `{ agent }` seam, which is how
// the round and conservation suites drive whole rounds. A mutation sweep showed `verifiedIds` could be narrowed to the threads
// the verification pass actually judged (rather than every thread it owns), and the closure set flipped on or
// off for a provisional result, both with the whole suite green — and both reintroduce bugs this branch fixed.
// Composition is where those live, so composition has to be assertable.
export function planRound({ threads, currentByFp, priorState = null, maxVerify = MAX_VERIFY_THREADS }) {
  const harnessThreads = threads.filter((t) => isHarnessComment(t.firstCommentAuthor));
  // The fingerprint a thread carries, and the finding it was: from the record when there is one, from the comment
  // body when there is not. The record is the reason this no longer has to parse its own rendered output — and it
  // knows the finding's text and severity exactly, rather than recovering them from an emoji prefix.
  // ONE identity per harness thread, computed once and read by everything that decides anything about it: the
  // closure rule, the verification prompt and the verdict gate all take it from here. Each of those derived
  // severity and text from the rendered comment on its own before, and they disagreed the moment a body was
  // edited — which is the premise the record exists for. Measured: an `error` thread whose `**ERROR**` prefix
  // was gone read as severity-less, so a `not_applicable` verdict closed it, silently disabling the guard that
  // says an error closes only on a fix.
  const identities = new Map();
  for (const t of harnessThreads) {
    const recorded = Object.values(priorState?.findings || {}).find((r) => r?.id === t.id);
    identities.set(t.id, {
      id: t.id,
      fp: fingerprintOfThread(t, priorState),
      // The record knows these exactly; the fallback recovers them from the rendered comment, which is lossy in
      // both directions.
      path: recorded ? recorded.file : t.path,
      severity: recorded ? recorded.severity : findingSeverity(t.firstCommentBody),
      // Truncated on BOTH paths, to the same length the record stores. A record's text is a prefix, so comparing
      // it against a full body text is the worst of both: measured 0.988 similarity falling to 0.552 on a
      // 472-character comment, which is the difference between recognising a moved finding and not.
      text: (recorded ? recorded.text : stripHarnessMarkup(t.firstCommentBody || '')).slice(0, MAX_STATE_TEXT),
      // What the verification pass shows the model, which wants as much of the finding as it can get rather than
      // the 160-character prefix the matcher compares. The BODY is the fuller text and is preferred while it
      // still looks like ours (a severity prefix or a fingerprint marker); once it has been edited past
      // recognition, the record's prefix is the only true text there is.
      // Bounded like every other PR-author-influenced string that reaches a prompt: a maintainer can paste
      // anything into a comment body, and this one goes into the verifier's prompt.
      promptText: (bodyLooksOurs(t.firstCommentBody) || !recorded
        ? stripHarnessMarkup(t.firstCommentBody || '')
        : recorded.text
      ).slice(0, MAX_VERIFY_CHARS),
    });
  }
  // Straight off the map, with no fallback object: the loop above sets an identity for every thread in
  // `harnessThreads` and every caller iterates that same array, so a fallback could not fire — and what it was is
  // a SECOND construction of the identity shape, free to drift from the one above and carrying `fp: undefined`,
  // which would make a thread invisible to `openUnreported` rather than loudly wrong. One shape, one place.
  const fpOf = (t) => identities.get(t.id)?.fp;
  // Which thread is the harness treating as the carrier of each fingerprint: the FIRST, exactly as reconcile
  // does. A second thread with the same fingerprint is not kept, not closed and not reported by reconcile — so
  // it belongs to the verification pass, which can say it is a duplicate. Before this it was in no bucket at
  // all: invisible for as long as its finding kept being reported. Reachable through the window that
  // `cancel-in-progress` leaves (a cancelled run that had already posted, and a successor that listed threads
  // seconds earlier).
  const carrierOfFp = new Map();
  for (const t of harnessThreads) {
    const fp = fpOf(t);
    if (fp && !carrierOfFp.has(fp)) carrierOfFp.set(fp, t.id);
  }
  // Every open thread of ours this round is not answering by re-reporting it. Nothing here is closed: closing a
  // thread is a judgement about code, and the verification pass is the only thing in this harness that reads
  // code. Resemblance used to close them (`planClosures`, deleted): file + severity + a Dice score over the
  // comment texts. Two genuinely different findings in one file measure 0.889 against a 0.5 bar — a still-valid
  // finding retired as a "duplicate", unverified, and recorded as closed. Similarity cannot tell "the same
  // finding, at a new line" from "two findings worded alike"; the model reading both texts AND the code can.
  const openUnreported = harnessThreads
    .filter((t) => !t.isResolved)
    .map((t) => ({ t, fp: fpOf(t) }))
    .filter(({ t, fp }) => fp && (!currentByFp.has(fp) || carrierOfFp.get(fp) !== t.id))
    .map(({ t }) => t);
  const toVerify = openUnreported.slice(0, maxVerify);
  const overflow = openUnreported.slice(maxVerify); // left for the next run, never resolved unverified
  return {
    identities,
    toVerify,
    overflow,
  };
}

// Decide what to do with each verified thread. Pure apart from `io`, so the trust rules are unit-tested:
// a human's "accepted" needs a maintainer reply on the thread, and the model may never invent one.
// The newest comment comes from listReviewThreads' own `last` selection: `comments` is capped, so its tail is not
// necessarily the newest on a long thread.
// True when the comment window this thread was fetched with dropped something: the opening comment is always
// included by its own selection, so if the window's first entry is not it, the window is truncated. `harnessClosed`
// reads that window, so on a thread past 30 comments it cannot see our own note and would re-post it every push.
const windowTruncated = (t) => Array.isArray(t.comments) && t.comments.length > 0 && t.firstCommentId != null && t.comments[0]?.id !== t.firstCommentId;

export const answeredAlreadyForTest = (t) => answeredAlready(t); // the repeat-suppression rule, unit-tested

export function answeredAlready(t) {
  // A truncated window cannot prove we have NOT already answered, so it counts as answered: repeating the same
  // note on every push is worse than staying quiet on a long thread.
  return windowTruncated(t) || harnessClosed(t, [MARKER_VERIFY_NOTE]);
}

// True when this harness wrote one of `markers` on the thread and no maintainer has spoken since. Both halves
// matter: the markers are public strings that anyone can paste, so only a comment the harness authored counts,
// and a maintainer's word after ours is a decision to respect rather than something to reopen or talk over.
// Our own action comes from the record; only the external half — has a maintainer spoken since — still needs the
// comments. That is the split the whole record exists for: marker archaeology over a window that silently
// truncates was deciding a question we already knew the answer to.
// No 'superseded': nothing has ever written it as an action — `closedRecords` writes 'resolved' and 'duplicate',
// `carriedRecords` writes 'open' — so no record can carry it and this could never match it. The word is taken
// anyway: `superseded` is the boolean on a `previously` row that `renderSummary` reads, and having it here made
// the two look related.
const HARNESS_CLOSE_ACTIONS = new Set(['resolved', 'duplicate']);

// Exported for the test that pins the carried-entry action OUT of this set: an entry that read as a close
// would have the next round reopening a thread that was never closed.
export const HARNESS_CLOSE_ACTIONS_FOR_TEST = HARNESS_CLOSE_ACTIONS;

export function harnessClosedByRecord(t, priorState) {
  const record = Object.values(priorState?.findings || {}).find((r) => r?.id === t.id);
  if (!record || !HARNESS_CLOSE_ACTIONS.has(record.action)) return null; // no record of us closing it: fall back
  const comments = Array.isArray(t.comments) ? t.comments : [];
  // A recorded close that we have spoken after is not our last word on the thread. Two overlapping runs make this
  // reachable: A closes T and records it, B sees the finding return and reopens T, then A's summary write lands
  // after B's and the record asserts the close again. If a maintainer then resolves T silently, believing the
  // record would unresolve their decision on every push. Comparing against the stamp costs nothing and needs no
  // knowledge of run order — GitHub honours no conditional write on a comment PATCH, so ordering is not available.
  if (record.at && comments.some((c) => isHarnessComment(c.author) && (c.createdAt || '') > record.at)) return null;
  // A maintainer's word after ours is a decision to respect, whatever our record says we did. Their timestamp is
  // compared against the record's commit-time proxy: the newest harness comment we can see.
  const oursAt = comments.filter((c) => isHarnessComment(c.author)).map((c) => c.createdAt || '').sort().pop() || '';
  const maintainerAt = comments
    .filter((c) => !isHarnessComment(c.author) && MAINTAINER_ASSOCIATIONS.has(c.association))
    .map((c) => c.createdAt || '')
    .sort()
    .pop();
  if (maintainerAt && oursAt && maintainerAt > oursAt) return false;
  return true;
}

export function harnessClosed(t, markers = HARNESS_RESOLVED_MARKERS, priorState = null) {
  // The record answers ONE question — "did we close this thread?" — because close actions are all it holds. This
  // function is also used to ask a different one: "have we already left a verify note on this open thread?", and
  // for that a recorded close is not an answer at all. It is safe today only because the caller asking the second
  // question passes no `priorState`; someone threading it through for consistency with `reconcile` would silently
  // make every thread with a recorded close read as "already answered", suppressing the note that says a
  // maintainer's reply did not settle the finding. So the record path is gated on which question is being asked.
  const recorded = markers === HARNESS_RESOLVED_MARKERS ? harnessClosedByRecord(t, priorState) : null;
  if (recorded !== null) return recorded;
  const carries = (body) => markers.some((m) => String(body || '').includes(m));
  const comments = Array.isArray(t.comments) ? t.comments : [];
  if (!comments.length) return isHarnessComment(t.lastCommentAuthor) && carries(t.lastCommentBody);
  // The *newest* harness comment must be the one carrying the marker. An older marker does not mean we hold the
  // thread: after we reopen a finding ("reported again"), a human who then resolves it silently has the last word
  // on the resolution, and reopening it again on the strength of that stale marker would be nagging. (`resolvedBy`
  // cannot settle this — the harness resolves with REVIEW_RESOLVE_TOKEN, so its resolutions show as its owner.)
  let ours = null;
  let maintainerAt = null;
  for (const c of comments) {
    if (isHarnessComment(c.author)) ours = { at: c.createdAt || '', marked: carries(c.body) };
    else if (MAINTAINER_ASSOCIATIONS.has(c.association)) maintainerAt = c.createdAt || '';
  }
  if (!ours || !ours.marked) return false;
  return maintainerAt === null || maintainerAt <= ours.at;
}

// Reconcile the current findings against the PR's existing review threads. Pure apart from `io`, so the
// four outcomes — post new, keep open, reopen auto-resolved, leave human-dismissed, resolve stale — are unit-tested.

// Word-set Dice over two finding texts. Deleted once already, and reinstated deliberately for a DIFFERENT
// job: it may decide whether two texts are the same finding, and it may never decide to close a thread. The
// asymmetry is the whole point. Closing on resemblance retires a live finding silently (measured: two real
// findings in one file at 0.889); MATCHING on resemblance, wrongly, costs one extra comment that a human can
// see. So the direction a mistake falls in is the test of where this may be used.
const contentWords = (text) =>
  new Set(
    String(text || '')
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .toLowerCase()
      .replace(/[^a-z0-9_.`/]+/g, ' ')
      .split(' ')
      .filter((w) => w.length > 3),
  );

export function findingSimilarity(a, b) {
  const A = contentWords(a);
  const B = contentWords(b);
  if (!A.size || !B.size) return 0;
  let shared = 0;
  for (const w of A) if (B.has(w)) shared++;
  return (2 * shared) / (A.size + B.size);
}

// Measured on the collision that produced this function: two different findings that shared a fingerprint
// scored 0.000, and the same finding re-reported on the next push scored 0.905. The bar sits far from both, and
// it errs toward "not the same finding", which posts a comment rather than merging two.
const SAME_FINDING_SIMILARITY = 0.35;

// The bar for a CLAIM the agent made, rather than a guess the harness made. Lower on purpose: the model has
// read both texts and the code, so it is better placed than a word-overlap score, and this only has to catch a
// claim that is obviously about something else. Refusing costs one extra comment; accepting a wrong claim would
// hide a finding, so it is not zero either.
const CLAIMED_SAME_FINDING_SIMILARITY = 0.12;

// Errors first wherever findings are ordered: the inline cap and the prompt's open-findings list both cut
// from the end, and a human needs the severe ones in context.
export const SEVERITY_RANK = { error: 0, warn: 1, info: 2 };

// The findings still open from earlier pushes, numbered for the review prompt. This is what lets the agent
// STATE which of its findings is an old one rather than leaving the harness to infer it from a hash: the two
// collision bugs on this branch were both that inference going wrong. Bounded, severity-first, harness threads
// only, and open only — a resolved thread is not the agent's business.
export function openFindings(threads = [], priorState = null, max = MAX_OPEN_FINDINGS_SHOWN) {
  const ours = threads.filter((t) => isHarnessComment(t.firstCommentAuthor) && !t.isResolved);
  const seen = new Set();
  const out = [];
  for (const t of ours) {
    const fp = fingerprintOfThread(t, priorState);
    if (!fp || seen.has(fp)) continue; // one entry per finding; a second thread for one fp is the verifier's problem
    seen.add(fp);
    const recorded = Object.values(priorState?.findings || {}).find((r) => r?.id === t.id);
    const anchor = threadAnchor(t);
    out.push({
      fp,
      file: recorded ? recorded.file : t.path,
      line: anchor.line ?? recorded?.line ?? null,
      // Carried through to the block: an outdated thread's line is from the commit the finding was raised on.
      stale: anchor.stale,
      severity: (recorded ? recorded.severity : findingSeverity(t.firstCommentBody)) || 'info',
      // The body while it still looks like ours, the record's text once a maintainer has edited it past
      // recognition — the same choice `identities` makes, for the same reason.
      text: (bodyLooksOurs(t.firstCommentBody) ? stripHarnessMarkup(t.firstCommentBody || '') : recorded?.text || '').slice(0, MAX_VERIFY_CHARS),
    });
  }
  out.sort((a, b) => (SEVERITY_RANK[a.severity] ?? 9) - (SEVERITY_RANK[b.severity] ?? 9));
  return out.slice(0, max).map((f, i) => ({ ...f, n: i + 1 }));
}

// The block the review prompt carries, and the id -> fingerprint map the harness reads a `same_as` claim
// against. Same escaping as every other PR-influenced string that reaches a prompt.
export function openFindingsBlock(list) {
  if (!list.length) return '';
  const rows = list
    .map((f) => `  <finding id="${f.n}" file="${escapeAttr(f.file)}" line="${escapeAttr(String(f.line ?? 'unknown'))}"${f.stale && f.line != null ? ` ${STALE_ANCHOR_ATTR}` : ''} severity="${escapeAttr(f.severity)}">${escapePrText(f.text)}</finding>`)
    .join('\n');
  return `\n\nFindings from earlier pushes on this PR that are still open. If one of your findings is the SAME ISSUE as
one of these — even at a different line, even worded differently — set \`same_as\` to its id instead of writing it
as new. Do not set \`same_as\` for a different problem that happens to be nearby.\n\n<open_findings>\n${rows}\n</open_findings>`;
}

// Posted when a finding is matched to a thread that does not already carry its text — a rewording the model
// made, or a `same_as` claim that put it there. Silence was the bug: "kept" counted the finding as handled and
// the thread went on showing its original text, so whatever the new wording said was seen by nobody.
//
// The test is CONTAINMENT, not resemblance, and that is the point. The conservation fuzzer's findings are
// near-identical boilerplate by construction, so no similarity score can tell a correct `same_as` claim from a
// wrong one — and neither can one in real life, where two findings in a file share most of their vocabulary.
// So the harness stops trying: whatever identity was decided, if the thread does not literally contain this
// finding's text, the text goes on the thread. A misplaced finding then sits visibly on the wrong thread, where
// a maintainer can see it and argue; a misplaced finding that is never printed is simply gone.
//
// It is also self-limiting: after the reply, the thread DOES contain that text, so the same wording is never
// posted twice however many pushes report it.
export const rewordedNote = (text) =>
  `Reported again on the newest commit, worded differently — the current wording is:\n\n${text}\n\n${MARKER_REWORDED}`;

// Keying the round's findings. One rule, applied to every claim on a fingerprint, whether the claimant is
// another finding from THIS round or a thread from an earlier one: a fingerprint is sha1(file|line|severity),
// which identifies a LOCATION, so a match is a candidate that has to be corroborated by what is already there.
//
// Both halves were live bugs, and both lost a finding without a word:
//   * across rounds, an `info` about `FALLBACK_MODEL` at review.mjs:57 and an `info` about `duplicateNote` at
//     review.mjs:57 shared a fingerprint, so the second was read as a re-report of the first — thread reopened,
//     record overwritten, and the verification pass then closed that thread on the OTHER finding's evidence;
//   * within one round, two findings at one location were merged into a single comment, and if that location
//     already had a thread the merged text was never posted anywhere: `stats.kept` counted the finding as
//     handled while the thread still showed only the original text. Found by the conservation fuzzer.
//
// So: same location AND recognisably the same finding ⇒ one comment carries both (a genuine double report).
// Same location, different finding ⇒ the newcomer is keyed with a text digest and gets its own comment. A wrong
// answer costs one extra comment a human can see; the answer it replaces cost a finding.
export function keyFindings(findings, threads = [], priorState = null, claims = new Map()) {
  const ours = threads.filter((t) => isHarnessComment(t.firstCommentAuthor));
  const threadByFp = new Map();
  for (const t of ours) {
    const fp = fingerprintOfThread(t, priorState);
    if (fp && !threadByFp.has(fp)) threadByFp.set(fp, t);
  }
  // What a thread SAYS, preferring its own body: the record's entry for it may already have been overwritten by
  // a colliding finding, which is the state this function exists to detect.
  const textOfThread = (t) => {
    if (!t) return '';
    if (bodyLooksOurs(t.firstCommentBody)) return stripHarnessMarkup(t.firstCommentBody || '');
    const recorded = Object.values(priorState?.findings || {}).find((r) => r?.id === t.id);
    return recorded?.text || '';
  };
  const out = new Map();
  let merged = 0;
  let collided = 0;
  let claimed = 0;
  let refused = 0;
  for (const f of findings) {
    // A CLAIM first, where there is one: the agent was shown the open findings and said this is one of them.
    // That is the fact this harness has been inferring — badly, twice — from a hash of a location. It is still
    // corroborated, but generously: the model read both texts and the code, so only a claim that looks like a
    // different finding entirely is refused, and a refusal costs an extra comment rather than a lost finding.
    // An id that was never offered is ignored outright.
    // Coerced, then validated. The contract asks for `"same_as": 3` and `"same_as": "3"` is a routine model slip,
    // which `Number.isInteger` used to discard in silence — so the finding was posted as new and collected a
    // second comment on a thread it already had, which is the churn this protocol exists to remove, with nothing
    // in the log to say why. Coercing widens nothing: the corroboration below (same file, and the wording read
    // against the thread's) is what actually admits a claim, and an id nobody offered still resolves to nothing.
    // Digits only, and positive: ids are 1-based, and a bare `Number()` maps `''` and `[]` to 0 — an integer, so
    // they would pass this check and then quietly match no claim, which is the same silent drop in a new place.
    const claimId =
      typeof f.same_as === 'number' ? f.same_as
        : typeof f.same_as === 'string' && /^\s*\d+\s*$/.test(f.same_as) ? Number(f.same_as)
          : NaN;
    if (f.same_as !== undefined && f.same_as !== null && !(Number.isInteger(claimId) && claimId > 0)) {
      console.warn(`ignoring an unusable same_as (${boundedDump(JSON.stringify(f.same_as), 120)}) at ${boundedDump(f.file, 80)}:${f.line}; treating the finding as new`);
    }
    const claimedFp = Number.isInteger(claimId) && claimId > 0 ? claims.get(claimId) : undefined;
    if (claimedFp) {
      const claimedThread = threadByFp.get(claimedFp);
      const theirs = textOfThread(claimedThread);
      // A finding moves lines; it does not move files. A claim naming a thread in another file is refused
      // whatever the wording says — the one constraint here that rests on a fact rather than a resemblance, and
      // the only one that holds when two findings are worded almost identically (which is the normal case for
      // two findings about the same kind of mistake).
      const sameFile = !claimedThread || (claimedThread.path || '') === f.file;
      if (sameFile && (!theirs || findingSimilarity(theirs, f.comment) >= CLAIMED_SAME_FINDING_SIMILARITY)) {
        claimed++;
        const already = out.get(claimedFp);
        out.set(claimedFp, already ? { ...already, comment: `${already.comment}\n\n---\n\n${f.comment}` } : { ...f });
        continue;
      }
      refused++;
      console.warn(
        `refusing same_as:${claimId} at ${boundedDump(f.file, 80)}:${f.line} — ` +
          `${sameFile ? 'the finding on that thread reads as a different one' : `that thread is on ${boundedDump(claimedThread.path, 80)}`}; posting this as new`,
      );
    }
    let fp = fingerprint(f);
    const claimant = out.get(fp)?.comment ?? textOfThread(threadByFp.get(fp));
    if (claimant && findingSimilarity(claimant, f.comment) < SAME_FINDING_SIMILARITY) {
      fp = fingerprint({ ...f, salt: String(f.comment || '').slice(0, MAX_STATE_TEXT) });
      collided++;
    }
    const existing = out.get(fp);
    if (existing) {
      // The same finding, reported twice in one round: one thread carrying both texts, rather than one of them
      // going missing. Copied rather than mutated — the caller's array is its own, and a function that edits
      // what it was handed is a trap for the next reader (it bit this file's own test).
      out.set(fp, { ...existing, comment: `${existing.comment}\n\n---\n\n${f.comment}` });
      merged++;
      continue;
    }
    out.set(fp, { ...f });
  }
  if (claimed) console.log(`${claimed} finding(s) the agent identified as already-open ones, kept on their threads`);
  if (refused) console.warn(`${refused} same_as claim(s) refused: the thread named carries a different finding`);
  if (merged) console.log(`Merged ${merged} finding(s) reported twice at one location`);
  if (collided) console.warn(`${collided} finding(s) landed where a different finding already lives; each keyed and posted on its own`);
  return out;
}
