// Minimal GitHub REST + GraphQL helpers for the PR reviewer.
// REST is used for issue/inline comments; GraphQL is used to enumerate and RESOLVE
// review threads (there is no REST endpoint for resolving a review thread).

const REST = 'https://api.github.com';
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
const API_TIMEOUT_MS = 30_000;

// Retried only for reads, and only for the failures that pass on their own: a 5xx, a secondary-rate-limit 403,
// a 429, or a timeout. One transient 502 from the thread listing otherwise costs every inline comment on that push
// (the harness skips them rather than risk duplicates), and one on the diff costs the whole run. Writes are never
// retried: a repeated POST would post a second comment.
const RETRY_TRIES = 3;
const isRetryableStatus = (status) => status >= 500 || status === 429 || status === 403; // 406 is deliberate: not retried
const retryableError = (e) => e?.name === 'TimeoutError' || e?.name === 'AbortError' || e?.code === 'ECONNRESET' || e instanceof TypeError;
const backoffMs = (attempt) => 500 * 2 ** attempt + Math.floor(Math.random() * 250);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchRead(url, options, label) {
  let lastError;
  for (let attempt = 0; attempt < RETRY_TRIES; attempt++) {
    if (attempt) await sleep(backoffMs(attempt - 1));
    try {
      const res = await fetch(url, options());
      // A plain 403 is usually "not permitted" and will not pass, but the secondary rate limit uses 403 too and
      // says so; retrying a permission error three times only costs a second.
      if (!res.ok && isRetryableStatus(res.status) && attempt < RETRY_TRIES - 1) {
        lastError = new Error(`${label} -> ${res.status}`);
        console.warn(`${label} -> ${res.status}; retrying (${attempt + 1}/${RETRY_TRIES - 1})`);
        continue;
      }
      return res;
    } catch (e) {
      if (!retryableError(e) || attempt === RETRY_TRIES - 1) throw e;
      lastError = e;
      console.warn(`${label} failed (${e.name || e.message}); retrying (${attempt + 1}/${RETRY_TRIES - 1})`);
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
    throw new Error(`${label} -> ${res.status}: ${text}`);
  }
  return res.status === 204 ? null : res.json();
}

async function graphql(queryStr, variables, tok) {
  const res = await fetch(GQL, {
    method: 'POST',
    headers: headers(tok),
    body: JSON.stringify({ query: queryStr, variables }),
    signal: AbortSignal.timeout(API_TIMEOUT_MS),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.errors) {
    throw new Error(`GitHub GraphQL -> ${res.status}: ${JSON.stringify(json.errors || json)}`);
  }
  return json.data;
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
  for (; page <= maxPages; page++) {
    const files = await rest('GET', `/repos/${owner}/${name}/pulls/${prNumber}/files?per_page=100&page=${page}`);
    if (!Array.isArray(files) || files.length === 0) break;
    for (const f of files) {
      const header = `diff --git a/${f.previous_filename || f.filename} b/${f.filename}`;
      parts.push(f.patch ? `${header}\n--- a/${f.previous_filename || f.filename}\n+++ b/${f.filename}\n${f.patch}` : `${header}\n[no patch returned by the API: binary or too large — ${f.status}, +${f.additions}/-${f.deletions}]`);
    }
    if (files.length < 100) break;
  }
  if (!parts.length) throw new Error('GitHub returned no files for this PR');
  if (page > maxPages) {
    // Only claim truncation once another page is known to exist: a change set that is an exact multiple of the
    // cap fetches every file and would otherwise be reported as incomplete, telling the agent to distrust a whole
    // diff. Say it in the diff itself, not just the log, since that is what the agent reads.
    const beyond = await rest('GET', `/repos/${owner}/${name}/pulls/${prNumber}/files?per_page=1&page=${maxPages * 100 + 1}`).catch(() => []);
    if (Array.isArray(beyond) && beyond.length) {
      console.warn(`Diff rebuilt from files was truncated at ${maxPages} pages`);
      parts.push(`[diff truncated: more than ${maxPages * 100} files changed — the rest was not fetched]`);
    }
  }
  return `${parts.join('\n')}\n`;
}

// ---------- Summary (issue-level) comments ----------

export async function listIssueComments(prNumber) {
  const { owner, name } = repo();
  const all = [];
  let page = 1;
  for (;;) {
    const batch = await rest(
      'GET',
      `/repos/${owner}/${name}/issues/${prNumber}/comments?per_page=100&page=${page}`,
    );
    if (!Array.isArray(batch) || batch.length === 0) break;
    all.push(...batch);
    if (batch.length < 100) break;
    page++;
  }
  return all;
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
export async function listReviewThreads(prNumber) {
  const { owner, name } = repo();
  const threads = [];
  let cursor = null;
  for (;;) {
    const data = await graphql(
      `query($owner:String!,$name:String!,$number:Int!,$cursor:String){
        repository(owner:$owner,name:$name){
          pullRequest(number:$number){
            reviewThreads(first:100, after:$cursor){
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
                last: comments(last:1){ nodes{ body author { login } createdAt } }
              }
            }
          }
        }
      }`,
      { owner, name, number: prNumber, cursor },
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
        firstCommentId: node.first?.nodes?.[0]?.databaseId ?? null,
        firstCommentBody: node.first?.nodes?.[0]?.body || '',
        firstCommentAuthor: node.first?.nodes?.[0]?.author?.login || '',
        // From its own selection, not the capped list: a thread with >30 comments would otherwise report the 30th.
        // The author comes with it: the harness's markers are public strings, so a marker only counts as ours
        // when we wrote the comment carrying it.
        lastCommentBody: node.last?.nodes?.[0]?.body || '',
        lastCommentAuthor: node.last?.nodes?.[0]?.author?.login || '',
        lastCommentAt: node.last?.nodes?.[0]?.createdAt || '',
      });
    }
    if (!conn.pageInfo.hasNextPage) break;
    cursor = conn.pageInfo.endCursor;
  }
  return threads;
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
