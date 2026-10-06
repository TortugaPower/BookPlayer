# The AI PR reviewer

Runs on every push to a PR against `develop` (`.github/workflows/claude-review.yml`), reviews the
diff with a Claude agent, and keeps the result as review comments on the PR. **The VERDICT is advisory** — a
`fail` never blocks a merge, and a human still merges. The check goes red only when the harness itself could not
run or could not post its result: a failed install, a red `node --test test/`, or a summary that could not be
written (which throws, by design — see below).

`review-guide.md` (one directory up) is the reviewer's rubric — what to flag, at what severity, what to skip.
It is the file to edit to change *what* gets reviewed. `repo.mjs` names this repository's secret files and secret
shapes. Those two are the per-repository files; everything else here is the harness that runs them, and ports
unchanged.

## Layout

One module per seam, so a change is read in the file that owns it:

| File | Owns |
| --- | --- |
| `review.mjs` | The round: `runReview` composes the rest, owns the budgets and the order of operations. The entry point. |
| `sandbox.mjs` | What the agent may run, read and see, and what may leave the process: the Bash grammar and its allowlists, the path rules, `agentEnv`, the write tokens withheld while the agent runs, `redact`. |
| `repo.mjs` | **Per repository.** The secret files the path rules refuse by name, and the secret shapes `redact` scrubs after the generic ones. |
| `identity.mjs` | Which finding is which across pushes: fingerprints, `same_as`, the state record, the markers, `planRound`. |
| `prompts.mjs` | What the reviewing agent is told; loads `review-guide.md` into the system prompt. |
| `agent.mjs` | The SDK seam: the options that are the sandbox in practice (including the tool gate as a PreToolUse hook), the run loop, model resolution, the result parsers. Everything the tests stub is behind `runAgent`. |
| `verify.mjs` | The verification pass, and `applyVerification` — the only thing that closes a thread. |
| `summary.mjs` | The sticky summary: rendering, the record it carries, the size budget, the failure notes, `upsertSummary`. |
| `github.mjs` | The bounded GitHub client: timeouts, read-only retry ladders, paged listings that report truncation. |
| `config.mjs` | Environment access, read at call time. |
| `smoke.mjs` | The install check the workflow runs: loads the SDK and runs the native CLI binary it will spawn. |

## What a round does

1. Fetches the PR and its diff (the agent gets no token; the diff is written to `RUNNER_TEMP`).
2. **Review pass** — the agent reads the diff and the checkout with read-only tools and returns JSON findings.
3. Identity. A finding's identity in the record is the thread it lives on, plus the id of the comment the harness
   created for it — a round that posts a comment cannot know its thread id (the listing was read first), so
   without the comment id the round after a post falls back to the marker in the body, and one maintainer edit of
   that body loses the finding. The prompt lists the findings still open from earlier pushes, and the agent may answer
   `same_as: <id>` to say "this is that one again" — identity **stated** rather than inferred. Where it says
   nothing, the fallback is a fingerprint, `sha1(file|line|severity)`, corroborated against what the thread
   actually says: that hash identifies a *location*, and two different findings at one location used to become
   one. A finding matched to a thread that does not already carry its text gets that text posted as a reply, so
   no decision about identity — the agent's or the harness's — can bury a finding's wording.
4. A finding whose identity already has a comment is left alone; a new one is posted inline; one that cannot be
   anchored (no such line in the diff, past the 25-comment cap, a refused post) is listed in the summary.
5. **Verification pass** — a second agent judges up to 20 still-open threads this round did *not* re-report against
   the current code: `fixed`, `present`, `not_applicable`, `accepted` (a maintainer said so), `insufficient`,
   or `duplicate` of a finding this push reports. **This is the only thing that closes a thread.** Absence
   closes nothing; an `error` closes only on evidence of a fix or a maintainer's own resolve. Past that cap the
   rest are listed in the summary as *not checked this round* and carried to the next, so on a long-lived PR a
   thread can go a round unjudged — it is never closed unjudged, which is the property that matters.
6. Writes one summary comment, which carries a hidden state record (`<!-- bp-ai-review-state:… -->`) of what
   this round did: which thread carries which finding, what was closed and why. The next round reads it instead
   of re-deriving its own history from rendered comments.

## Running the tests

```
cd .github/claude/reviewer && npm ci --ignore-scripts && node --test test/
```

~246 tests, a minute or so, no network and no API key. The reviewer workflow runs them in a job of their own —
without secrets, since they are the pull request's code — whenever a pull request touches this directory or the
workflow. The review itself runs the base branch's harness, so a red suite here does not stop a review; it stops
the change from being the reviewer once merged. This harness
ports by copying this directory, `review-guide.md` and `claude-review.yml`, and nothing in it assumes the rest of
your CI — the directory carries its own `.gitignore` for `node_modules/`, so the copy is complete without touching
the root one. Then edit the two per-repository files: `review-guide.md` (what to review) and `repo.mjs` (which
files hold secrets, which shapes to scrub); a copy that keeps this repository's lists gets rules that match
nothing of its own. And create the `reviewer` environment with a deployment-branch policy for your base branches
and put the two secrets in it (see Tokens) — the workflow's trust split depends on it.

**And mutate the DOUBLE, not only the code.** The fake GitHub answered a posted comment with the id of the
comment created *next* — off by one, for as long as it has existed, because nothing had ever read that value.
The first code that did read it mis-identified every thread, and the conservation law reported it as lost
findings. A double that lies is worse than one that refuses.

`test/workflow.test.mjs` reads `claude-review.yml` — the harness's own workflow, which ports with it — and does
the budget arithmetic: every step bounded, the step caps fitting inside the job cap with slack, the review step's cap looser than the harness's own budget (so
`review.mjs` is what ends that step, not the runner), the two failure notes mutually exclusive and gated on
`failure()` rather than `always()`, and — the drift-killer — every cap named in a comment matching the real
number. Three consecutive review rounds found bugs in that file, all of them arithmetic nobody could check.
**When a comment names a cap, write it as "the job's N" or "the review step's N"**, which is the form that test
reads.

`test/comments.test.mjs` checks that every identifier a comment names exists in the code, with an allowlist for
the ones deliberately naming deleted code or something external — each entry carrying its reason. This harness is
commented heavily on purpose, which makes a wrong comment expensive: it is what a maintainer reads before
touching the code. Five wrong ones have been found by review so far, and this catches the sharpest kind.

`test/shell-allowlist.test.mjs` holds the unit tests — the tool gate, the record, the prompts, the budgets.
`test/round.test.mjs` runs whole rounds through `runReview({ agent })` with `fetch` stubbed and the model
faked, which is where composition bugs show up.

**When you change behaviour, mutate it.** The discipline this harness is held to: make the change, then break
it on purpose and check a test fails. Most of the bugs found in it were found that way, and most of them lived
in code that was already covered by a test that could not see them.

## Running it locally

```
DRY_RUN=1 \
ANTHROPIC_API_KEY=… GITHUB_TOKEN=$(gh auth token) \
GITHUB_REPOSITORY=TortugaPower/BookPlayer PR_NUMBER=1586 \
COMMIT=$(gh pr view 1586 --json headRefOid --jq .headRefOid) BASE_REF=develop \
RUNNER_TEMP=/tmp/reviewer \
node .github/claude/reviewer/review.mjs
```

Run from a checkout of the pull request's branch: with `REVIEW_CHECKOUT` unset the agent reads the current
directory (in CI the workflow sets it to the pull request's checkout, beside the harness it executes).

`DRY_RUN=1` reads GitHub for real (PR, diff, comments) and runs the real agent, then prints the findings and
the summary it *would* post. Every write path sits behind that flag, so nothing reaches the PR — including
`--setup-failed`, whose note is gated inside `appendNoteToSummary` so no caller can forget it (one did). Drop the flag
only against a PR you are happy to have commented on.

To exercise the plumbing without spending a model call, stub the agent as the round tests do:
`runReview({ agent: async () => ({ finalText: '```json\n{…}\n```', resultSubtype: 'success' }) })`.

## Knobs

| env | default | what it does |
| --- | --- | --- |
| `REVIEW_MODEL` | unset | Pins the model. Unset = newest Opus-tier id from the Models API, with a fallback list. |
| `REVIEW_DEADLINE_MS` | 12 min | The review pass's own clock. |
| `REVIEW_JOB_BUDGET_MS` | 18 min | Both passes plus setup. The review is capped by this minus the verify slice. |
| `REVIEW_RECONCILE_NETWORK_MS` | 4 min | What the write phase may spend on network retries after the passes. The phase is unclocked; its GitHub calls are not. |
| `REVIEW_VERIFY_BUDGET_MS` | 5 min | Reserved for the verification pass; under 60 s left, it is skipped and the summary says so. |
| `REVIEW_MAX_TURNS` | 40 in code, 200 in the workflow | Runaway guard only; the real bound is the deadline. |
| `REVIEW_MAX_OUTPUT_TOKENS` | 32,000 | Per model response. A finding list cut off mid-JSON is reported as a partial round, and closes nothing. |
| `DRY_RUN` | off | Read everything, write nothing. |
| `ACTIONS_STEP_DEBUG` | off | Raises the agent-output dump in the log from 4 KB to 20 KB. A public repo's log is public. |
| `REVIEW_CHECKOUT` | the workspace | The pull request's tree: what the agent reads and the path rules confine it to. Set by the workflow. |

Raising `REVIEW_DEADLINE_MS` or `REVIEW_JOB_BUDGET_MS` means raising `timeout-minutes` in the workflow with
them — both the job's and the review step's. The harness's clock has to be the tighter of the two: its budget is
measured from before the model lookup and the reconcile phase after it is unclocked (up to 25 posts plus a
resolve and a reply per closed thread), so a step cap set too close cancels the round mid-write. Every step is
bounded, because a job cancelled by ITS OWN timeout runs no `if: failure()` step at all — the note saying the
reviewer did not run would never fire. A step killed anyway (its cap, an OOM) is covered by the last step in the
workflow, which fires only when `review.mjs` did not manage to say anything itself.

## Tokens

**The job that holds the secrets never executes pull request code.** The workflow runs on `pull_request_target`,
so the workflow file that runs is the base branch's; the job checks the harness out from the base branch into
`harness/` and executes only that, and checks the pull request's tree out beside it as the thing the agent reads
(`REVIEW_CHECKOUT`). To the harness that tree is data, like the diff. The pull request's own harness tests run in
a second job that holds no secret, no environment and a read-only token. The consequence to know about: a pull
request that changes the harness is reviewed by the harness it is changing *from*; merging is what promotes it.

**The reviewer workflow's actions are pinned to commit SHAs**, version in a trailing comment
(`uses: actions/checkout@3d3c42e5… # v7.0.1`), and `test/workflow.test.mjs` fails on a mutable tag in this workflow: a tag can be moved onto different code by whoever holds it, and
this job holds the secrets. Fork pull requests are skipped at the job level on purpose (they would receive the
environment's secrets under `pull_request_target`), which is also why checkout v7's refusal to fetch a fork's head
never fires here and `allow-unsafe-pr-checkout` stays unset.

**The secrets belong in the `reviewer` environment, not in repository secrets.** That is the step that makes the
above hold repository-wide: any *other* `pull_request` workflow can be edited by a pull request to print a
repository secret, but an environment whose deployment-branch policy is `develop` hands its secrets only to runs
whose ref is that branch — which a `pull_request_target` run is and a `pull_request` run
(`refs/pull/N/merge`) is not. The environment is created on the workflow's first run; the branch policy and the
move of `ANTHROPIC_API_KEY` and `REVIEW_RESOLVE_TOKEN` into it (and their deletion at repository level) are
repository settings a maintainer makes once. Until they are made, the workflow still works off the repository
secrets — and is not protected.

**What this does not close.** The agent subprocess has to hold `ANTHROPIC_API_KEY` to call the model, and it reads
a tree the pull request author wrote. The boundary against the *model* exfiltrating it is the sandbox — `/proc/`
and `~` denied, no `env`/`curl`/`node -e` in the Bash grammar, `redact` on everything posted — which is a grammar,
and the key is still a long-lived secret. The next step, when wanted, is no long-lived key at all: GitHub OIDC to
AWS Bedrock (the SDK runs on it) with a role scoped to `bedrock:InvokeModel`, or to a small proxy that holds the
key and caps spend per run. Same for the PAT: a GitHub App token minted per run.

**Nothing watches this dependency tree.** It is installed in the job that holds `ANTHROPIC_API_KEY` and the
resolve PAT, and it pulls in express, ajv, jose and others; a vulnerable transitive dependency in the committed
lockfile stays invisible until somebody looks. Two ways to close that, both a maintainer's decision rather than
this harness's: a Dependabot npm entry scoped to this directory (its pull requests skip the reviewer, so there is
no loop), or `npm audit` run here whenever the SDK is bumped. Until one exists, this is a known residual.

The SDK version is **pinned exactly** (`0.3.280`, not `^0.3.280`), and that is a safety property rather than
tidiness: the agent's sandbox is configured entirely by SDK option *names* — `settingSources: []`,
`allowedTools: []`, `permissionMode: 'default'`, `canUseTool`, `env` — and every test stubs the agent seam, so a
release that renamed or stopped honouring one of them would pass the whole suite with the isolation silently
weakened. **Raising it means reading the options block in `agentQuery` against the SDK's current types**, which is
why the bump has to be an edit a human makes rather than a range that drifts.

- `ANTHROPIC_API_KEY` — environment secret (`reviewer`). The agent's environment is built by allowlist, so
  neither token below is visible to it.
- `REVIEW_RESOLVE_TOKEN` — optional but load-bearing: the default `GITHUB_TOKEN` cannot resolve review threads
  ("Resource not accessible by integration"), so without it every close fails, the threads stay open, and the
  summary says "could not be resolved" on each one. A fine-grained PAT scoped to this repository with
  **Pull requests: read & write** is enough — a classic repo-scope token over-reaches. To rotate: create the
  PAT, update the environment secret, and update the backup copy in SSM (the parameter name
  and account are in the internal runbook, not here) so a write-only GitHub secret is recoverable. **This
  repository is public**: the fact that a backup exists belongs in this file, its coordinates do not — they are
  free reconnaissance for anyone who later gets credentials for that account.

## Things worth knowing before changing it

- **Nothing closes a thread except a judgement.** Two earlier designs closed threads by resemblance (file +
  severity + a similarity score over the comment texts) and both retired live findings: two different findings
  in one file measure 0.889 against a 0.5 bar. If you are tempted again, the answer is a verdict from the
  verification pass, which reads the code.
- **A finding never leaves the PR silently, and `test/conservation.test.mjs` is where that is enforced.** It
  states the law rather than testing a mechanism, and fuzzes rounds against it against a GitHub whose state
  evolves — drifting lines, rewordings, collisions, edited bodies, human resolves, failed posts, and an agent
  that lies about `same_as`. It has caught two bugs the whole mutation-testing loop missed. When you change how
  identity or closing works, run it first; if it passes and you expected it to fail, your change probably does
  not do what you think. Its failure injections are where its blind spots have been: the thread read, the
  comment read, the inline post, the resolve, the reason-reply and the summary write can each be refused for a
  round. Every one of those was added after the round it could not see hid a real bug.
- **GitHub can refuse a write that landed.** Observed once: two inline posts answered `422 … "An internal error
  occurred, please try again"` and both comments were created anyway. The round reported them as not visible
  inline, which was wrong for one round and self-corrected on the next — the thread listing found them by their
  markers, so nothing was posted twice. Nothing in the harness checks whether a refused write landed; a read
  after every failed write would be code for a flake seen once, so this is recorded rather than handled.
- **A close the harness cannot explain on the thread is not made.** The reply carrying the reason goes AFTER the
  resolve on purpose (without `REVIEW_RESOLVE_TOKEN` every resolve fails, and reply-first would claim "verified
  fixed" on every thread that stayed open). A thread with no comment to reply to — GitHub can answer with an empty
  `first` selection — is judged, reported and left open rather than closed. And when the reply is refused after
  the resolve landed, **the close is undone**: leaving it standing rested on the summary row landing, and the
  round that cannot post a reply may be the round that cannot write its summary either, which leaves a resolved
  thread with no marker and no record entry — read by the next round as a maintainer's own resolve, filing a
  returning finding as `dismissed` for good. The flapping objection that kept it closed for twenty rounds died
  with the `firstCommentId` pre-check, which refuses the one permanent cause before the resolve. Residual: both
  writes refused, where the close stands, the row says so, and the record carries it.
- **The re-wording reply is bounded by CONTAINMENT, and the churn that buys is accepted.** When a carried-over
  finding comes back worded differently, the new wording is posted on its thread unless the thread literally
  contains it. A similarity guard (skip if ~0.9 alike) was proposed and turned down: two wordings that differ by
  one word — `unregistered in onStop` against `unregistered in onDestroy` — score above that bar, and suppressing
  the second buries the part a maintainer needs. The projected cost was one reply per carried finding per push;
  measured over 23 rounds and 150 threads on this PR, it was **6 replies**, because a finding usually comes back
  in the same words (containment suppresses it) or has been fixed. Cheap enough not to trade the invariant for.
- **Similarity may decide MATCHING, never CLOSING.** A wrong match costs an extra comment somebody can see; a
  wrong close costs a finding. Every use of `findingSimilarity` is on the first side of that line.
- **The record is the harness's memory, and every summary write replaces the comment it lives in.** Any path
  that writes a summary must carry a record — its own, or the one it read. Two bugs came from a path that
  wrote one without.
- **A summary that cannot be written is a fatal error, not a warning.** It is the round's only durable output:
  the findings that could not be posted inline live in it, and so does the record. Swallowing the failure let a
  round report findings, put none of them anywhere, and exit 0 — indistinguishable, on an advisory check, from
  a clean review. It throws now, and the job goes red. The one exception is a summary comment that has been
  *deleted* (404/410), where posting a new one is right; any other refusal must not post, because a second
  summary means two records.
- **The agent's Bash is a grammar, not an emulator.** `analyzeShell` accepts only what it can prove it has
  parsed exactly as bash would (the words it sees ARE the argv), and flags are allowlisted per command in full
  spelling, because `getopt_long` accepts any unambiguous prefix. Adding a command means adding its flags, and
  anything that follows symlinks, never returns, or takes filenames from a file stays out.
- **The write tokens leave the process while the agent runs.** `agentEnv` filters what is handed to the SDK, and
  whether the subprocess is spawned with that or with `{ ...process.env, ...options.env }` is the SDK's business —
  a release that merged would make the filtering cosmetic with every test still green. So `GITHUB_TOKEN` and
  `REVIEW_RESOLVE_TOKEN` are deleted from `process.env` for the duration of the call and restored in a `finally`.
  The wrapper sits at the agent SEAM, not inside `runAgent`: every implementation passes through it, including the
  stubs the tests drive rounds with, so the guarantee is observable rather than asserted.
- **Everything the model writes is untrusted at the write boundary.** `redact()` runs on every body, reply and
  record field, and on every log line in every module — `github.mjs` cannot import it, so `sandbox.mjs` hands it over
  at startup (`setLogRedactor`) and until then the client withholds error messages rather than logging them raw.
  `neutralizeMarkup` stops model text from opening an HTML comment, which is what keeps a
  finding from forging a state record or a fingerprint marker. The same applies to the answer itself: the review's
  result is taken from the terminal fenced block the output contract mandates, so a result-shaped example quoted
  inside a finding — this file's own guide contains one — cannot be adopted as the round's answer.
