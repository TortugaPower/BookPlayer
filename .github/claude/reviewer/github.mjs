// Minimal GitHub REST + GraphQL helpers for the PR reviewer.
// REST is used for issue/inline comments; GraphQL is used to enumerate and RESOLVE
// review threads (there is no REST endpoint for resolving a review thread).

const REST = 'https://api.github.com';
// One constant for the page size and for the "was that page full?" test. They were two bare 100s in two loops,
// so changing the page size — the obvious thing to do to save a request — silently stopped pagination after the
// first page: the agent would review the first slice of a large diff with no truncation marker, and the harness
// would read only the first page of comments, losing its own state record and posting a second summary.
// One page size for every listing in this file, REST and GraphQL alike. The GraphQL query kept its own literal
// `first:100` for a while, and `MAX_THREAD_PAGES`' arithmetic ("100 pages is 10,000 threads") silently depended
// on it — so halving this would have left that comment and the `truncated` reasoning wrong without touching
// anything named `PER_PAGE`. (`$cursor` in that query is a GraphQL variable, not a template hole; only `${`
// interpolates.)
//
// 100 is the MAXIMUM both APIs accept — REST caps `per_page` there, and GraphQL rejects `first:` above it with
// MAX_NODE_LIMIT_EXCEEDED — so this may only be lowered. Raising it fails the thread listing outright, which
// `runReview` catches into a round that posts nothing inline.
export const PER_PAGE = 100;
const GQL = 'https://api.github.com/graphql';

function token() {
  const t = process.env.GITHUB_TOKEN;
  if (!t) throw new Error('GITHUB_TOKEN env var is required');
  return t;
}

export function repo() {
  const full = process.env.GITHUB_REPOSITORY; // "owner/name"
  if (!full) throw new Error('GITHUB_REPOSITORY env var is required');
  const [owner, name] = full.split('/');
  return { owner, name, full };
}

function headers(tok) {
  return {
    Authorization: `Bearer ${tok || token()}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };
}

// A stalled GitHub call should fail into the harness's degrade paths, not sit until the job timeout.
export const API_TIMEOUT_MS = 30_000;

// Retried only for reads, and only for the failures that pass on their own: a 5xx, a secondary-rate-limit 403,
// a 429, or a timeout. One transient 502 from the thread listing otherwise costs every inline comment on that push
// (the harness skips them rather than risk duplicates), and one on the diff costs the whole run. Writes are never
// retried: a repeated POST would post a second comment.
export const RETRY_TRIES = 3;
// The wall clock this file may not run past. `review.mjs` sets it from the same budget its own deadlines come
// from: without it, a retry ladder is bounded only by attempts x timeout, and nested inside the GraphQL transient
// loop that was 9 HTTP calls of up to 30 s each — 4.6 minutes for one page of threads, spent before the review
// even starts and unaccounted for by any budget.
let networkDeadline = Infinity;
export const setNetworkDeadline = (epochMs) => {
  networkDeadline = epochMs;
};
const outOfTime = () => Date.now() >= networkDeadline;
// For the test that pins `runReview()` SETTING it: the budget functions are pure and pinned, the call that arms
// them was not, and an unarmed ladder is retries outside every budget the run has.
export const networkDeadlineForTest = () => networkDeadline;
// The log boundary, injected for the same reason the deadline is. `review.mjs` states the rule — every string that
// leaves the process goes through `redact`, log lines included — and its checker used to read only that file, so
// the two warnings below that quote a thrown error's message sat outside a rule described as absolute. Today they
// only ever see undici's own text ("fetch failed", a timeout), but `rest()` puts the whole upstream body in ITS
// message, and "nothing that reaches this line carries a body" is a property of the callers, not of this line.
// This file cannot import `redact` (that would be a cycle), so the function is handed in at startup, and until
// it is the boundary fails CLOSED: a message is withheld, not passed through. The error's NAME is logged either
// way — it is a class name from undici or this runtime, never upstream text.
let redact = () => '[message withheld: no redactor installed]';
export function setLogRedactor(fn) {
  redact = fn;
}
export const logRedactorForTest = () => redact;
// 406 is deliberate (the diff is too large to render), and a bare 403 is usually "not permitted", which will not
// pass however often it is tried. The secondary rate limit also answers 403, and says so in its headers.
// Only the SECONDARY limit, which clears on this timescale and says so with Retry-After. The primary hourly limit
// also answers 403, with x-ratelimit-remaining: 0, but it resets at x-ratelimit-reset — up to an hour out — so
// retrying it three times half a second apart burns the attempts and fails anyway.
const rateLimited = (res) => Boolean(res.headers?.get?.('retry-after'));
const isRetryableResponse = (res) => res.status >= 500 || res.status === 429 || (res.status === 403 && rateLimited(res));
// A network failure surfaces as TypeError, but so does a programming error in the request options — retrying
// that three times and reporting it as a network problem hides the real cause. undici sets `cause` on the
// network kind and says "fetch failed".
const retryableError = (e) =>
  e?.name === 'TimeoutError' ||
  e?.name === 'AbortError' ||
  e?.code === 'ECONNRESET' ||
  (e instanceof TypeError && (e.cause !== undefined || /fetch failed|network/i.test(e.message || '')));
export const backoffMs = (attempt) => 500 * 2 ** attempt + Math.floor(Math.random() * 250);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchRead(url, options, label) {
  let lastError;
  for (let attempt = 0; attempt < RETRY_TRIES; attempt++) {
    if (attempt) {
      // Never spend the run's remaining time on a retry: the caller's degrade paths are more useful than one more
      // attempt, and this is the file that used to be able to eat the whole budget.
      if (outOfTime()) throw lastError || new Error(`${label}: out of time for a retry`);
      await sleep(backoffMs(attempt - 1));
    }
    try {
      const res = await fetch(url, options());
      if (!res.ok && isRetryableResponse(res) && attempt < RETRY_TRIES - 1) {
        lastError = new Error(`${label} -> ${res.status}`);
        console.warn(`${label} -> ${res.status}; retrying (${attempt + 1}/${RETRY_TRIES - 1})`);
        continue;
      }
      return res;
    } catch (e) {
      if (!retryableError(e) || attempt === RETRY_TRIES - 1) throw e;
      lastError = e;
      console.warn(`${label} failed (${e.name || 'Error'}: ${redact(e.message)}); retrying (${attempt + 1}/${RETRY_TRIES - 1})`);
    }
  }
  throw lastError;
}

async function rest(method, path, body) {
  const url = path.startsWith('http') ? path : `${REST}${path}`;
  const options = () => ({
    method,
    headers: headers(),
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(API_TIMEOUT_MS),
  });
  const label = `GitHub ${method} ${path}`;
  const res = method === 'GET' ? await fetchRead(url, options, label) : await fetch(url, options());
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    // The status as a property, not only inside the message: a caller that has to tell "the comment I meant to
    // update is gone" (404/410, where posting a new one is right) from "GitHub refused this write" (where
    // posting one would duplicate the summary) should not have to parse prose to do it.
    throw Object.assign(new Error(`${label} -> ${res.status}: ${text}`), { status: res.status });
  }
  return res.status === 204 ? null : res.json();
}

// `retry` is set for the read query only. It is a POST like every GraphQL call, so it cannot be inferred from the
// method: a retried resolve/unresolve would be a second mutation. The thread listing is the one that matters —
// a transient 502 there costs every inline comment on that push, since the harness skips them rather than
// risk duplicates.
// GraphQL answers 200 with an `errors` array for its most common transient failures, so status alone does not
// decide: those are retried here, after parsing, and everything else throws on the first answer.
const TRANSIENT_GQL_ERROR = /RATE_LIMITED|SERVICE_UNAVAILABLE|INTERNAL|TIMEOUT/i;
async function graphql(queryStr, variables, tok, { retry = false, label = 'GitHub GraphQL' } = {}) {
  const options = () => ({
    method: 'POST',
    headers: headers(tok),
    body: JSON.stringify({ query: queryStr, variables }),
    signal: AbortSignal.timeout(API_TIMEOUT_MS),
  });
  for (let attempt = 0; ; attempt++) {
    // Plain fetch, not fetchRead: this loop IS the retry for the read query, and nesting the two multiplied
    // 3 attempts into 9 (and 90 s of timeouts into 270 s).
    //
    // Thrown failures are retried HERE, with the same predicate `fetchRead` uses. Without this the ladder covered
    // only HTTP statuses and GraphQL `errors` arrays — so the 30-second `AbortSignal.timeout` firing, or a socket
    // reset, threw on the FIRST attempt. That is the exact failure the comment above says this exists for: it
    // costs every inline comment on the push, because `runReview` catches it, reviews with `threads = null`, and
    // reconcile never runs.
    let res;
    let json;
    try {
      res = await fetch(GQL, options());
      json = await res.json().catch(() => ({}));
    } catch (e) {
      if (!retry || attempt >= RETRY_TRIES - 1 || outOfTime() || !retryableError(e)) throw e;
      console.warn(`${label} failed (${e.name || 'Error'}: ${redact(e.message)}); retrying (${attempt + 1}/${RETRY_TRIES - 1})`);
      await sleep(backoffMs(attempt));
      continue;
    }
    if (res.ok && !json.errors) return json.data;
    const transient =
      retry &&
      attempt < RETRY_TRIES - 1 &&
      !outOfTime() &&
      (isRetryableResponse(res) ||
        (Array.isArray(json.errors) &&
          json.errors.some((e) => TRANSIENT_GQL_ERROR.test(`${e?.type || ''} ${e?.message || ''}`))));
    if (!transient) throw new Error(`${label} -> ${res.status}: ${JSON.stringify(json.errors || json)}`);
    // A 5xx reaches here too, since this loop replaced the nested ladder for the read query.
    console.warn(`${label} -> transient GraphQL error; retrying (${attempt + 1}/${RETRY_TRIES - 1})`);
    await sleep(backoffMs(attempt));
  }
}

// ---------- Pull request metadata + diff (fetched by the harness so the agent needs no token) ----------

export async function getPullRequest(prNumber) {
  const { owner, name } = repo();
  const pr = await rest('GET', `/repos/${owner}/${name}/pulls/${prNumber}`);
  return { title: pr.title || '', body: pr.body || '', author: pr.user?.login || '' };
}

export async function fetchPullRequestDiff(prNumber) {
  const { owner, name } = repo();
  const res = await fetchRead(
    `${REST}/repos/${owner}/${name}/pulls/${prNumber}`,
    () => ({
      headers: { ...headers(), Accept: 'application/vnd.github.diff' },
      // A longer cap than the JSON calls: this one streams the whole diff body, and AbortSignal.timeout bounds the
      // entire exchange rather than idle time, so a big PR on a slow link would otherwise abort mid-download.
      signal: AbortSignal.timeout(API_TIMEOUT_MS * 4),
    }),
    `GitHub GET diff #${prNumber}`,
  );
  if (res.ok) return res.text();
  // GitHub answers 406 for a diff it will not render (very large PRs). The per-file endpoint still serves the
  // patches, so stitch them together rather than failing the whole review.
  if (res.status === 406) {
    console.warn('Diff endpoint refused this PR (406); rebuilding it from the per-file patches');
    return fetchDiffFromFiles(prNumber);
  }
  const text = await res.text().catch(() => '');
  throw new Error(`GitHub GET diff -> ${res.status}: ${text}`);
}

// A unified diff assembled from `pulls/{n}/files`. Each file carries its own `patch`; a file GitHub omits a patch
// for (binary, or too large on its own) is named so the agent knows it changed and was not shown.
export async function fetchDiffFromFiles(prNumber, maxPages = 30) {
  const { owner, name } = repo();
  const parts = [];
  let page = 1;
  let lastPageFull = false;
  for (; page <= maxPages; page++) {
    const files = await rest('GET', `/repos/${owner}/${name}/pulls/${prNumber}/files?per_page=${PER_PAGE}&page=${page}`);
    if (!Array.isArray(files) || files.length === 0) break;
    for (const f of files) {
      const header = `diff --git a/${f.previous_filename || f.filename} b/${f.filename}`;
      // /dev/null on the missing side, as a real unified diff has it: the rubric leans on "is this file new"
      // (a committed .env, an endpoint added without validation), and naming both sides made every added file
      // read as a modification.
      const from = f.status === 'added' ? '/dev/null' : `a/${f.previous_filename || f.filename}`;
      const to = f.status === 'removed' ? '/dev/null' : `b/${f.filename}`;
      parts.push(f.patch ? `${header}\n--- ${from}\n+++ ${to}\n${f.patch}` : `${header}\n[no patch returned by the API: binary or too large — ${f.status}, +${f.additions}/-${f.deletions}]`);
    }
    lastPageFull = files.length === PER_PAGE;
    if (!lastPageFull) break;
    // The last paging loop in this file without a clock, and the one with the most room to run: 30 sequential
    // pages at the 30-second request timeout is most of the review's whole budget, spent BEFORE the review pass
    // starts — and `rest()`'s deadline check stops retries, never fresh pages. The other two loops were hardened
    // for exactly this; the agent is told in the diff itself, because the diff is what it reads.
    if (outOfTime()) {
      console.warn('Diff rebuild stopped: out of time');
      parts.push('[diff truncated: the harness ran out of time listing this PR\'s files — anything beyond this point is not shown]');
      break;
    }
  }
  if (!parts.length) throw new Error('GitHub returned no files for this PR');
  if (page > maxPages && lastPageFull) {
    // The cap was reached and the last page was full, so the change set is at least this large. Probing one page
    // further cannot tell us more — GitHub serves at most 3000 files from this endpoint, exactly the default cap,
    // so the probe came back empty every time and this marker could never appear. Say it in the diff itself, not
    // only the log: the diff is what the agent reads.
    console.warn(`Diff rebuilt from files stopped at the ${maxPages}-page cap`);
    parts.push(`[diff truncated: ${maxPages * PER_PAGE} files listed, which is all GitHub serves from this endpoint — anything beyond that is not shown]`);
  }
  return `${parts.join('\n')}\n`;
}

// ---------- Summary (issue-level) comments ----------

// 20 pages = 2,000 comments. The thread listing has had a cap since an unbounded loop was found able to defeat
// every degrade path the harness has (the job just runs to `timeout-minutes` with no comment on the PR); this
// loop had none, and 50 sequential pages at up to 30 s each is the same failure by a slower road.
const MAX_COMMENT_PAGES = 20;
// Every caller wants exactly ONE comment: this harness's own summary. It is not fetched any more cheaply than
// this — `sort`/`direction` are documented on the REPOSITORY-wide comments endpoint, not on this per-issue one,
// and it ignores them (verified against the API: identical order with and without). No matter, since the summary
// is CREATED on the first round and this order is chronological, so it is on page 1 of almost any PR.
// Returns `{ comments, truncated }`. `truncated` is the whole point: a list that stopped early is
// indistinguishable from a complete one, and every caller here is looking for ONE comment — this harness's own
// summary. Not finding it then means either "there is no summary yet" or "we did not look at all of them", and
// those lead opposite ways: the first says post a new summary, the second would post a SECOND one and drop the
// state record with it. So the fact travels with the data.
export async function listIssueComments(prNumber) {
  const { owner, name } = repo();
  const comments = [];
  let truncated = false;
  for (let page = 1; page <= MAX_COMMENT_PAGES; page++) {
    const batch = await rest(
      'GET',
      `/repos/${owner}/${name}/issues/${prNumber}/comments?per_page=${PER_PAGE}&page=${page}`,
    );
    if (!Array.isArray(batch) || batch.length === 0) break;
    comments.push(...batch);
    if (batch.length < PER_PAGE) break;
    // The same clock the retry ladders use. Paging is the other way this file can run past the end of the job:
    // 20 pages x 30 s is 10 minutes.
    if (outOfTime()) {
      console.warn('Comment listing stopped: out of time');
      truncated = true;
      break;
    }
    if (page === MAX_COMMENT_PAGES) {
      console.warn(`Comment listing stopped at the ${MAX_COMMENT_PAGES}-page cap`);
      truncated = true;
    }
  }
  return { comments, truncated };
}

export async function postIssueComment(prNumber, body) {
  const { owner, name } = repo();
  return rest('POST', `/repos/${owner}/${name}/issues/${prNumber}/comments`, { body });
}

export async function updateIssueComment(commentId, body) {
  const { owner, name } = repo();
  return rest('PATCH', `/repos/${owner}/${name}/issues/comments/${commentId}`, { body });
}

// ---------- Inline (review) comments ----------

export async function postInlineComment({ prNumber, commitId, path, line, body }) {
  const { owner, name } = repo();
  return rest('POST', `/repos/${owner}/${name}/pulls/${prNumber}/comments`, {
    body,
    commit_id: commitId,
    path,
    line,
    side: 'RIGHT',
  });
}

// ---------- Review threads (dedup source + resolve) ----------

// Every review thread on the PR: identity, resolution state, where it is anchored, and its full comment list
// (author login + association, so the harness can tell a maintainer's reply from anyone else's).
//
// Returns `{ threads, truncated }`, for the same reason `listIssueComments` does and with worse consequences if
// it did not: `reconcile` builds its "which finding already has a comment" map from this list, so every thread
// past a silent cut looks like a finding with no comment and gets a SECOND inline comment, and
// `carriedRecords` drops the remembered closes for those threads. A short list is worse than no list, so the
// caller is told rather than left to guess.
const MAX_THREAD_PAGES = 100;
export async function listReviewThreads(prNumber) {
  const { owner, name } = repo();
  const threads = [];
  let truncated = false;
  let cursor = null;
  for (let page = 1; ; page++) {
    const data = await graphql(
      `query($owner:String!,$name:String!,$number:Int!,$cursor:String){
        repository(owner:$owner,name:$name){
          pullRequest(number:$number){
            reviewThreads(first:${PER_PAGE}, after:$cursor){
              pageInfo{ hasNextPage endCursor }
              nodes{
                id
                isResolved
                path
                line
                originalLine
                # Three selections, because they answer three different questions and a long thread makes them
                # disagree: the opening comment (which carries the fingerprint marker), the newest 30 (whose
                # marker came after whose reply), and the newest one (is our note the last word).
                first: comments(first:1){ nodes{ databaseId body author { login } } }
                comments(last:30){ nodes{ databaseId body author { login } authorAssociation createdAt } }
                last: comments(last:1){ nodes{ body author { login } } }
              }
            }
          }
        }
      }`,
      { owner, name, number: prNumber, cursor },
      undefined,
      { retry: true, label: 'GitHub GraphQL reviewThreads' },
    );
    const conn = data.repository.pullRequest.reviewThreads;
    for (const node of conn.nodes) {
      const comments = (node.comments?.nodes || []).map((c) => ({
        id: c.databaseId ?? null,
        body: c.body || '',
        author: c.author?.login || '',
        association: c.authorAssociation || 'NONE',
        createdAt: c.createdAt || '',
      }));
      threads.push({
        id: node.id,
        isResolved: node.isResolved,
        path: node.path || '',
        // Distinct on purpose: `line` is null exactly when the thread is outdated, and `originalLine` then points
        // into the commit the finding was raised on — a stale anchor the caller must not present as current.
        line: node.line ?? null,
        originalLine: node.originalLine ?? null,
        comments,
        // From the `first` selection: on a thread past 30 comments, comments[0] is no longer the opening one,
        // and the fingerprint marker lives in the opening comment.
        firstCommentId: node.first?.nodes?.[0]?.databaseId ?? null, // `??`, not `||`: 0 is a valid id
        firstCommentBody: node.first?.nodes?.[0]?.body || '',
        firstCommentAuthor: node.first?.nodes?.[0]?.author?.login || '',
        // From its own selection, not the capped list: a thread with >30 comments would otherwise report the 30th.
        // The author comes with it: the harness's markers are public strings, so a marker only counts as ours
        // when we wrote the comment carrying it.
        lastCommentBody: node.last?.nodes?.[0]?.body || '',
        lastCommentAuthor: node.last?.nodes?.[0]?.author?.login || '',
      });
    }
    // A null cursor with hasNextPage true would re-request the FIRST page forever: verified by probe, and an
    // infinite loop here defeats every degrade path the harness has — the job just runs to timeout-minutes with no
    // comment. The page cap is the second backstop; 100 pages is 10,000 threads.
    if (!conn.pageInfo.hasNextPage || !conn.pageInfo.endCursor) break;
    if (page >= MAX_THREAD_PAGES) {
      console.warn(`Thread listing stopped at the ${MAX_THREAD_PAGES}-page cap`);
      truncated = true;
      break;
    }
    // 100 pages x 30 s is 50 minutes — past the job's 48 on its own — so the page loop honours the network deadline too,
    // not only the retry ladder inside each call.
    if (outOfTime()) {
      console.warn('Thread listing stopped: out of time');
      truncated = true;
      break;
    }
    cursor = conn.pageInfo.endCursor;
  }
  return { threads, truncated };
}

// Reply inside an existing review thread (used to leave the auto-resolve marker).
export async function replyToReviewComment(prNumber, commentId, body) {
  const { owner, name } = repo();
  return rest('POST', `/repos/${owner}/${name}/pulls/${prNumber}/comments/${commentId}/replies`, { body });
}

export async function unresolveReviewThread(threadId) {
  const tok = process.env.REVIEW_RESOLVE_TOKEN || process.env.GITHUB_TOKEN;
  return graphql(
    `mutation($threadId:ID!){
      unresolveReviewThread(input:{threadId:$threadId}){ thread{ id isResolved } }
    }`,
    { threadId },
    tok,
  );
}

export async function resolveReviewThread(threadId) {
  // The default GITHUB_TOKEN (github-actions[bot]) is NOT allowed to resolve review threads
  // ("Resource not accessible by integration"), even with pull-requests: write. If a PAT / App
  // token is provided via REVIEW_RESOLVE_TOKEN, use it for the resolve mutation; otherwise fall
  // back to GITHUB_TOKEN (which will fail — threads then only show as GitHub's auto "Outdated").
  const tok = process.env.REVIEW_RESOLVE_TOKEN || process.env.GITHUB_TOKEN;
  return graphql(
    `mutation($threadId:ID!){
      resolveReviewThread(input:{threadId:$threadId}){ thread{ id isResolved } }
    }`,
    { threadId },
    tok,
  );
}
