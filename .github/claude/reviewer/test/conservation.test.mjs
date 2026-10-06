// The law: a finding this harness has reported never leaves the pull request silently.
//
// Every foundation failure on this branch has been one shape — the harness acted on an inference, and a wrong
// inference lost a finding without saying so. A bash emulator inferred argv; marker archaeology inferred the
// harness's own history; a similarity score inferred "these two texts are the same finding"; a fingerprint
// inferred identity from a location. Each was fixed by obtaining the fact or refusing to act without it, and
// each was found by someone looking from outside — never by the local loop, because a mutation sweep pins the
// behaviour a design has, and says nothing about whether the design is right.
//
// So this file does not test a mechanism. It states the property all of them exist to serve, and fuzzes rounds
// against it: findings appear, drift to new lines, get reworded, collide on a line another finding already
// occupies; maintainers edit comment bodies and resolve threads; posts, resolves and the record read fail. The
// verifier is scripted to answer `present` for everything — nothing is ever fixed — so NOTHING may be closed,
// and after every round each finding ever reported must still be findable on the PR: carried by an open thread,
// or named in the summary as unpostable or unjudged. Being carried by SEVERAL threads is churn rather than
// loss — the verifier's `duplicate` verdict is what collapses those, and this scripted verifier never issues
// one — so duplication is bounded instead of forbidden.
//
// Each finding carries an oracle token (`[F7]`) that survives rewording, so the check is exact string
// containment rather than a judgement of its own — and a SECOND tag per wording (`[W3]`), because the first
// one alone let the law pass vacuously exactly where it was needed: a finding that came back re-worded onto a
// thread the harness had closed was reopened with its new text posted nowhere, and the original comment still
// carried the finding's token. The law now asks for the CURRENT wording, not merely the finding.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { decodeState } from '../identity.mjs';

const MAIN = '../review.mjs';

// Deterministic RNG: a failing scenario has to be reproducible from its seed alone.
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 0x100000000;
  };
}

// A GitHub whose state evolves as the harness acts on it: posting opens a thread, replying appends to one,
// resolving flips it. Every earlier test in this suite serves a fixed snapshot, which cannot express "what the
// harness did last round is what it sees this round" — the axis all four failures lived on.
function worldGitHub() {
  let nextComment = 1000;
  let nextThread = 1;
  const state = { threads: [], summary: null, failPost: false, failResolve: false, failRecordRead: false, failThreadRead: false, failReply: false, failSummaryWrite: false };
  const calls = { posted: 0, resolved: 0, unresolved: 0, replies: 0, resolvedIds: [] };

  const threadNodes = () =>
    state.threads.map((t) => ({
      id: t.id,
      isResolved: t.isResolved,
      path: t.path,
      line: t.outdated ? null : t.line,
      originalLine: t.line,
      // A thread whose opening comment has been deleted: the body and author are still in the selection, the id
      // is not. GitHub answers `databaseId: null` there, `github.mjs` passes the null through deliberately, and
      // the harness then has a thread it can read but cannot reply to. Every reply the harness makes is a
      // promise it keeps about text reaching the pull request, so this is the shape that tests whether a reply
      // it CANNOT make is reported as one it did.
      first: { nodes: [{ databaseId: t.noReplyTarget ? null : t.comments[0].databaseId, body: t.comments[0].body, author: { login: t.comments[0].author } }] },
      comments: { nodes: t.comments.slice(-30).map((c) => ({ databaseId: c.databaseId, body: c.body, author: { login: c.author }, authorAssociation: c.association, createdAt: c.createdAt })) },
      last: { nodes: t.comments.slice(-1).map((c) => ({ body: c.body, author: { login: c.author }, createdAt: c.createdAt })) },
    }));

  const fetch = async (url, init = {}) => {
    const u = String(url);
    const method = init.method || 'GET';
    const body = init.body ? JSON.parse(init.body) : null;
    const ok = (json) => ({ ok: true, status: 200, headers: { get: () => null }, json: async () => json, text: async () => (typeof json === 'string' ? json : JSON.stringify(json)) });
    const fail = (status) => ({ ok: false, status, headers: { get: () => null }, json: async () => ({}), text: async () => 'injected failure' });

    if (u.endsWith('/graphql')) {
      if (/resolveReviewThread/.test(body.query) && !/unresolve/.test(body.query)) {
        if (state.failResolve) return fail(403);
        const t = state.threads.find((x) => x.id === body.variables.threadId);
        if (t) t.isResolved = true;
        calls.resolved++;
        calls.resolvedIds.push(body.variables.threadId);
        return ok({ data: { resolveReviewThread: {} } });
      }
      if (/unresolveReviewThread/.test(body.query)) {
        if (state.failResolve) return fail(403);
        const t = state.threads.find((x) => x.id === body.variables.threadId);
        if (t) t.isResolved = false;
        calls.unresolved++;
        return ok({ data: { unresolveReviewThread: {} } });
      }
      if (state.failThreadRead) return fail(502);
      return ok({ data: { repository: { pullRequest: { reviewThreads: { nodes: threadNodes(), pageInfo: { hasNextPage: false, endCursor: null } } } } } });
    }
    if (/\/pulls\/\d+$/.test(u) && (init.headers?.Accept || '').includes('diff')) return ok('diff --git a/x b/x\n@@ -1 +1 @@\n+x\n');
    if (/\/pulls\/\d+$/.test(u)) return ok({ title: 'a PR', body: 'a description', user: { login: 'author' } });
    if (/\/issues\/\d+\/comments/.test(u) && method === 'GET') {
      if (state.failRecordRead) return fail(500);
      return ok(state.summary ? [{ id: 99, user: { login: 'github-actions[bot]' }, body: state.summary }] : []);
    }
    if (/\/issues\/\d+\/comments/.test(u) && method === 'POST') {
      if (state.failSummaryWrite) return fail(500);
      state.summary = body.body;
      return ok({ id: 99 });
    }
    if (/\/issues\/comments\/\d+/.test(u) && method === 'PATCH') {
      if (state.failSummaryWrite) return fail(500);
      state.summary = body.body;
      return ok({ id: 99 });
    }
    if (/\/pulls\/\d+\/comments\/\d+\/replies/.test(u)) {
      if (state.failReply) return fail(422);
      const id = Number(/comments\/(\d+)\/replies/.exec(u)[1]);
      const t = state.threads.find((x) => x.comments[0].databaseId === id);
      if (t) t.comments.push({ databaseId: nextComment++, body: body.body, author: 'github-actions[bot]', association: 'NONE', createdAt: new Date().toISOString() });
      calls.replies++;
      return ok({ id: nextComment });
    }
    if (/\/pulls\/\d+\/comments/.test(u) && method === 'POST') {
      if (state.failPost) return fail(422);
      // The id of the comment it just created, which is what the real endpoint returns. It used to answer
      // `nextComment` AFTER the increment — every id one too high, pointing at the comment created NEXT — and
      // nothing read the value, so nothing noticed. The first code to read it (recording the id so a finding
      // posted this round has an identity that survives an edited body) then mis-identified every thread by one,
      // and the law reported it as lost findings. A double that lies is worse than one that refuses.
      const created = nextComment++;
      state.threads.push({
        id: `T${nextThread++}`,
        path: body.path,
        line: body.line,
        isResolved: false,
        outdated: false,
        comments: [{ databaseId: created, body: body.body, author: 'github-actions[bot]', association: 'NONE', createdAt: new Date().toISOString() }],
      });
      calls.posted++;
      return ok({ id: created });
    }
    throw new Error(`unstubbed ${method} ${u}`);
  };
  return { state, calls, fetch };
}

// The scripted model. The review pass reports the findings the scenario asks for; the verification pass answers
// `present` for every id it is given — nothing is ever fixed, so nothing may ever be closed.
//
// It also exercises the `same_as` protocol, and exercises it BADLY on purpose. The prompt now lists the open
// findings and invites the model to name the one its finding repeats, which moves identity from something the
// harness infers to something the model asserts — so the law has to hold when that assertion is right, when it
// is wrong (naming a thread about something else), and when it is nonsense (an id that was never offered). A
// model is not a contract; the fuzzer treats it as an adversary.
const scriptedAgent = (findings, claimPolicy = () => undefined, garnish = () => []) => async (prompt) => {
  const isVerify = prompt.includes('Below are findings reported on it by');
  if (isVerify) {
    // Nothing is ever fixed — so no thread may be closed on that basis. But this verifier DOES answer
    // `duplicate` when it can see that the finding it is judging is one this push reported elsewhere in the
    // same file, which is what production does and what collapses the churn a drifting line produces. It also
    // exercises the duplicate path, which has never run outside a test.
    const threads = [...prompt.matchAll(/<finding id="(\d+)"[^>]*>([\s\S]*?)<\/finding>/g)].map((m) => {
      const id = Number(m[1]);
      const block = m[2];
      const token = block.match(/\[F\d+\]/)?.[0];
      const twin = token
        ? [...block.matchAll(/<reported line="(\d+)"[^>]*>([\s\S]*?)<\/reported>/g)].find((r) => r[2].includes(token))
        : null;
      return twin
        ? { id, status: 'duplicate', of: Number(twin[1]), evidence: 'the same issue is reported at that line on this push' }
        : { id, status: 'present', evidence: 'the code still does this' };
    });
    return { finalText: '```json\n' + JSON.stringify({ threads }) + '\n```', lastAnswer: '', turns: 2, resultSubtype: 'success' };
  }
  // What the prompt offered, in the order it offered it: id -> the text of that open finding.
  const offered = [...prompt.matchAll(/<finding id="(\d+)"[^>]*>([\s\S]*?)<\/finding>/g)].map((m) => ({ id: Number(m[1]), text: m[2] }));
  const claimed = findings.map((f) => {
    const same_as = claimPolicy(f, offered);
    return same_as === undefined ? f : { ...f, same_as };
  });
  // Malformed elements the model can and does emit — null, prose, a finding whose comment is an object. They are
  // not findings, so the law does not count them; a round that dies on one is a round that reported nothing.
  const result = { verdict: claimed.length ? 'warn' : 'pass', summary: 'a round', findings: [...claimed, ...garnish()] };
  return { finalText: '```json\n' + JSON.stringify(result) + '\n```', lastAnswer: '', turns: 2, resultSubtype: 'success' };
};

async function loadHarness(env, tag) {
  const previous = {};
  for (const [k, v] of Object.entries(env)) {
    previous[k] = process.env[k];
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
  const mod = await import(`${MAIN}?conservation=${tag}`);
  return { mod, restore: () => { for (const [k, v] of Object.entries(previous)) { if (v === undefined) delete process.env[k]; else process.env[k] = v; } } };
}

// One scenario: a world of findings, and a sequence of rounds that mutate it the way real pushes do.
async function runScenario(seed) {
  const rand = rng(seed);
  const pick = (arr) => arr[Math.floor(rand() * arr.length)];
  const temp = realpathSync(mkdtempSync(join(tmpdir(), `law-${seed}-`)));
  const { mod, restore } = await loadHarness({
    GITHUB_REPOSITORY: 'TortugaPower/repo', GITHUB_TOKEN: 'tok', PR_NUMBER: String(100 + (seed % 800)),
    COMMIT: `c0${seed}`.padEnd(16, '0'), BASE_REF: 'develop', RUNNER_TEMP: temp, ANTHROPIC_API_KEY: 'k',
    RUN_URL: '', DRY_RUN: undefined, GITHUB_WORKSPACE: process.cwd(),
  }, `s${seed}`);
  const gh = worldGitHub();
  const realFetch = globalThis.fetch;
  globalThis.fetch = gh.fetch;

  const FILES = ['app/A.kt', 'app/B.kt'];
  const SEVERITIES = ['error', 'warn', 'info'];
  // The world's findings. `token` is the oracle's handle on each one and survives every rewording.
  let nextToken = 1;
  let nextWording = 1;
  const world = [];
  const newFinding = (over = {}) => {
    const token = `[F${nextToken++}]`;
    const f = { token, file: pick(FILES), line: 1 + Math.floor(rand() * 60), severity: pick(SEVERITIES), words: `the ${token} problem is that this call is never released on the lifecycle it belongs to`, reported: false, ...over };
    world.push(f);
    return f;
  };
  for (let i = 0; i < 3; i++) newFinding();

  const asFinding = (f) => ({ severity: f.severity, file: f.file, line: f.line, comment: f.words });
  const problems = [];

  // try/finally, because the stub is global: the law's own escape clause re-throws (a round that threw for a
  // reason other than the summary write), and an assertion or a TypeError anywhere in a scenario does the same —
  // which used to leave `globalThis.fetch` stubbed and the environment mutated for every seed after it, so one
  // real failure arrived wearing five confusing ones.
  try {
    for (let round = 1; round <= 6; round++) {
      // Mutations a real push makes.
      if (rand() < 0.4) { const f = pick(world); f.line = 1 + Math.floor(rand() * 60); }            // the line drifts
      // Reworded — and the new wording gets its own tag, so "is this finding still on the PR" and "is what it
      // says NOW on the PR" are different questions the law can ask separately.
      if (rand() < 0.3) { const f = pick(world); f.wording = `W${nextWording++}`; f.words = `${f.words} [${f.wording}] (still true at push ${round})`; }
      if (rand() < 0.35) {                                                                            // a NEW finding where one already lives
        const host = pick(world.filter((f) => f.reported)) || pick(world);
        newFinding({ file: host.file, line: host.line, severity: host.severity, words: `the [F${nextToken}] problem is a different one entirely: this receiver is registered twice` });
      }
      if (rand() < 0.25) newFinding();
      // A maintainer edits one of our comment bodies past recognition.
      if (rand() < 0.25 && gh.state.threads.length) {
        const t = pick(gh.state.threads);
        t.comments[0].body = 'I rewrote this while triaging';
      }
      // A maintainer resolves one of our threads themselves.
      if (rand() < 0.2 && gh.state.threads.length) {
        const t = pick(gh.state.threads.filter((x) => !x.isResolved));
        if (t) { t.isResolved = true; t.comments.push({ databaseId: 9000 + round, body: 'handled, thanks', author: 'gianni', association: 'OWNER', createdAt: new Date().toISOString() }); }
      }
      // GitHub outdates a thread whose anchor no longer maps.
      if (rand() < 0.2 && gh.state.threads.length) pick(gh.state.threads).outdated = true;
      // Somebody deletes the opening comment of one of our threads: the thread survives, its reply target does not.
      // Deliberately common (0.4, not the 0.15 the other injections use): the state that matters is this thread
      // ALSO being one the round decides to close, and at 0.15 the two coincided so rarely across twelve seeds that
      // removing the guard in the harness left the law green.
      if (rand() < 0.4 && gh.state.threads.length) pick(gh.state.threads).noReplyTarget = true;
      // Injected failures, one round at a time.
      gh.state.failPost = rand() < 0.15;
      gh.state.failResolve = rand() < 0.15;
      gh.state.failRecordRead = rand() < 0.15;
      // The thread listing failing was the fuzzer's own blind spot, and the bug it hid was exactly the one this
      // law is for: on that path the round posted nothing inline and the summary carried only COUNTS, so every
      // finding of that round left the PR without a word. Injected now, so the law sees it.
      gh.state.failThreadRead = rand() < 0.15;
      gh.state.failReply = rand() < 0.15;
      gh.state.failSummaryWrite = rand() < 0.1;

      // What the model reports this round: a random subset, so "not re-reported" happens constantly.
      const reporting = world.filter(() => rand() < 0.7);
      for (const f of reporting) f.reported = true;
      // How this round's model behaves about `same_as`: honest (name the open finding that carries this token),
      // careless (name a DIFFERENT open finding), inventive (an id nobody offered), or silent.
      const mood = rand();
      const claimPolicy = (f, offered) => {
        if (!offered.length || mood < 0.25) return undefined;
        const mine = offered.find((o) => o.text.includes(f.comment.match(/\[F\d+\]/)?.[0] || 'never'));
        if (mood < 0.6) return mine?.id;                                    // honest, when it can tell
        if (mood < 0.8) return offered.find((o) => o !== mine)?.id ?? mine?.id; // careless: someone else's thread
        return 999;                                                          // inventive: never offered
      };
      const resolvesBefore = gh.calls.resolvedIds.length;
      let threw = null;
      try {
        const garnish = () => (rand() < 0.2 ? [pick([null, 'nothing else to report', 42, [], { severity: 'warn', comment: 'no file' }, { severity: 'warn', file: 'g.kt', line: 3, comment: { text: 'an object' } }])] : []);
        await mod.runReview({ agent: scriptedAgent(reporting.map(asFinding), claimPolicy, garnish) });
      } catch (e) {
        threw = e;
      }
      // The law's own escape clause, and the only one: when GitHub refuses the writes, no mechanism can put a
      // finding on the pull request, so what the harness owes is a VISIBLE failure instead of a quiet one. A round
      // that threw has failed the job (`process.exit(1)` at the top level) and the check goes red. A round that
      // could not write its summary and returned normally is the forbidden state, and is what this catches.
      if (threw) {
        if (!/Could not post the summary comment/.test(threw.message)) throw threw;
        problems.push(...(gh.state.summary === null && !gh.state.failSummaryWrite ? [`seed ${seed} round ${round}: threw about the summary but the write was never refused: ${threw.message}`] : []));
        continue;
      }

      // THE LAW, in two halves.
      //
      // First: every finding the harness is STILL being told about, or that it has a comment for, must be
      // accounted for — carried by exactly one open thread, identified by the record as living on an open thread
      // (which is what happens when a maintainer wipes our comment body), named in the summary, or closed by a
      // human. Never simply absent. A finding the model has stopped reporting and that never got a comment is
      // outside this: the harness has no evidence it is still true and nothing to carry it on.
      //
      // Second: in the round where a finding could NOT be posted, that round's summary has to name it. That is
      // the harness's actual obligation to a finding it could not put inline, and the only thing that keeps the
      // first half honest about the case above.
      const summary = gh.state.summary || '';
      const record = decodeState(summary);
      const recordCarries = (token) =>
        Object.values(record?.findings || {}).some(
          (r) => String(r?.text || '').includes(token) && gh.state.threads.some((t) => t.id === r.id && !t.isResolved),
        );
      for (const f of world) {
        const anyThread = gh.state.threads.some((t) => t.comments.some((c) => c.body.includes(f.token)));
        const reportedNow = reporting.includes(f);
        if (!reportedNow && !anyThread) continue;
        const open = gh.state.threads.filter((t) => !t.isResolved && t.comments.some((c) => c.body.includes(f.token)));
        const closedByHuman = gh.state.threads.some(
          (t) => t.isResolved && t.comments.some((c) => c.body.includes(f.token)) && t.comments.some((c) => c.author !== 'github-actions[bot]'),
        );
        // One or more open threads is accounted for. MORE than one is churn, not loss — a wrong `same_as`, or a
        // finding that moved and got a second comment — and the thing that collapses it is the verifier's
        // `duplicate` verdict, which this scripted model never issues. Churn is bounded below instead.
        if (open.length >= 1 || closedByHuman || summary.includes(f.token) || recordCarries(f.token)) continue;
        const mine = gh.state.threads.filter((t) => t.comments.some((c) => c.body.includes(f.token)));
        problems.push(
          `seed ${seed} round ${round}: ${f.token} (${f.severity} ${f.file}:${f.line}, reported this round: ${reportedNow}) ` +
            `is accounted for nowhere — ${open.length} open thread(s) carry it, ${mine.length - open.length} resolved, ` +
            `in summary: ${summary.includes(f.token)}, in record on an open thread: ${recordCarries(f.token)}`,
        );
      }
      // And the CURRENT WORDING is on the PR, not just the finding. A finding matched to a thread that does not
      // carry its new text used to be counted as handled while the thread showed the old wording — on the kept
      // path once, and on the reopen path after that was fixed. Only a per-wording tag can see it.
      for (const f of world.filter((x) => x.reported && x.wording)) {
        const tag = `[${f.wording}]`;
        const onAThread = gh.state.threads.some((t) => t.comments.some((c) => c.body.includes(tag)));
        if (onAThread || summary.includes(tag) || !reporting.includes(f)) continue;
        problems.push(`seed ${seed} round ${round}: ${f.token} was re-reported as ${tag} and that wording is nowhere on the PR`);
      }
      // Churn has a ceiling. Every duplicate is a comment a human has to read, so unbounded duplication is its
      // own failure even though nothing is lost: six rounds of drifting lines and mistaken claims may leave a
      // finding on a few threads, not on a dozen.
      for (const f of world.filter((x) => x.reported)) {
        const carrying = gh.state.threads.filter((t) => t.comments.some((c) => c.body.includes(f.token)));
        const openCarrying = carrying.filter((t) => !t.isResolved);
        // Drift can outpace the collapse by one per round — a line moves, a comment is posted, and the verifier
        // collapses the old thread on the NEXT round — so a small steady state is expected. Growth without bound
        // is not: six rounds may not leave a finding open on six threads.
        if (openCarrying.length > 3) problems.push(`seed ${seed} round ${round}: ${f.token} is OPEN on ${openCarrying.length} threads`);
      }
      // The second half: a finding reported this round that ended up on no thread must be named in the summary.
      for (const f of reporting) {
        const onAThread = gh.state.threads.some((t) => t.comments.some((c) => c.body.includes(f.token)));
        if (onAThread || summary.includes(f.token) || recordCarries(f.token)) continue;
        problems.push(`seed ${seed} round ${round}: ${f.token} was reported and could not be posted, and the summary does not mention it`);
      }
      // Nothing here is ever FIXED, so every close the harness makes must be a duplicate close — and it must say
      // so on the thread. A close with no reason on it is the failure this law was written for: a thread that goes
      // quiet with no record of who closed it or why.
      // THIS round's closes, not every closed thread on the PR: the question is whether the round that closed a
      // thread explained itself, and a violation inherited from an earlier round would otherwise be re-reported for
      // ever, drowning the round that actually caused it. `resolvedIds` is what the round asked GitHub to resolve.
      const closedThisRound = new Set(gh.calls.resolvedIds.slice(resolvesBefore));
      const ourCloses = gh.state.threads.filter((t) => closedThisRound.has(t.id) && t.comments.every((c) => c.author === 'github-actions[bot]'));
      // And the rule that makes the row above an acceptable fallback at all: a close is only ever explained for one
      // round by the summary, since the next round's summary replaces it — so a thread the harness KNOWS it can
      // never reply to must not be closed in the first place. `noReplyTarget` is the world's truth (the opening
      // comment's id is gone), and `firstCommentId` is how the harness sees the same fact.
      for (const t of gh.state.threads) {
        if (closedThisRound.has(t.id) && t.noReplyTarget) {
          problems.push(
            `seed ${seed} round ${round}: thread ${t.id} was closed although it has no comment to reply to — ` +
              `nothing can ever put the reason on it, and a summary row lasts one round`,
          );
        }
      }
      // The reason has to be ON THE THREAD. This used to also accept "this round's summary row says the reply was
      // refused", which matched the harness's behaviour until round 29 — and that behaviour was wrong for a reason
      // this law could not see, because it excuses a round that threw on the summary write: the two failures
      // compound into a thread left resolved with no marker and no record entry, which the NEXT round reads as a
      // maintainer's own resolve. The harness undoes such a close now, so the escape clause has nothing left to
      // excuse and the law is stricter by exactly that much. Still uncovered: a refusal of the reply AND of the
      // unresolve, which this fuzzer cannot produce — `failResolve` governs both mutations at once.
      const saidOnTheThread = (t) => t.comments.some((c) => /same issue is reported on this push/.test(c.body));
      for (const t of ourCloses) {
        const explained = saidOnTheThread(t);
        if (!explained) {
          problems.push(
            `seed ${seed} round ${round}: thread ${t.id} was closed by the harness with no reason on it — ` +
              `nothing was fixed this round, so the only close available was a duplicate`,
          );
        }
      }
    }

  } finally {
    globalThis.fetch = realFetch;
    restore();
  }
  return problems;
}

test('no reported finding ever leaves the pull request silently', async () => {
  const found = [];
  for (const seed of [1, 7, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]) {
    found.push(...(await runScenario(seed)));
  }
  assert.deepEqual(found, [], `the conservation law failed:\n${found.slice(0, 12).join('\n')}`);
});
