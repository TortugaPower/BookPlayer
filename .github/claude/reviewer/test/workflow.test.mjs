// The workflow is part of the harness, and until now it was the part with no tests.
//
// Three consecutive review rounds found bugs in `claude-review.yml`, and all three were the same kind: arithmetic
// nobody could check. A hang burning the job's clock because the steps were unbounded; a step cap that turned out
// to be tighter than the harness's own budget, so the step was killed mid-write; step caps that summed to more
// than the job cap, so the job timeout could still be the binding one. Each was caught by a careful reader doing
// sums in their head, and each defeats the guarantee the rest of this harness is organised around — because a job
// cancelled by ITS OWN timeout runs no `if: failure()` step at all, so the note saying the reviewer did not run
// never fires: a red check, and nothing on the pull request.
//
// So the sums live here now. The reader below is deliberately strict rather than a YAML parser: it accepts only
// the shapes this file actually uses and throws on anything else, for the same reason `analyzeShell` does — a
// parser that guesses is a parser that agrees with you about a file you have misread.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const WORKFLOW = fileURLToPath(new URL('../../../workflows/claude-review.yml', import.meta.url));
const README = fileURLToPath(new URL('../README.md', import.meta.url));
// The harness is every module in the directory, read as one source: the budgets live in review.mjs, the caps in
// identity.mjs, the knobs in agent.mjs, and a check that read one file would have lost the others in the split.
const MODULES = readdirSync(fileURLToPath(new URL('..', import.meta.url))).filter((f) => f.endsWith('.mjs')).sort().map((f) => fileURLToPath(new URL(`../${f}`, import.meta.url)));
const harnessSource = () => MODULES.map((f) => readFileSync(f, 'utf8')).join('\n');
// Everywhere a budget figure can be written down. Adding a file here is the cheap half of keeping these two
// checks honest; the expensive half is remembering that a check over a FILE LIST is only as wide as the list.
//
// Every path it names is declared ABOVE it, and the call below proves it: naming one that is declared later works
// only while nothing invokes this during module evaluation, and precomputing the list — the natural next edit —
// throws on the temporal dead zone, which in this file would look like the drift checks losing their corpus.
const capSources = () => [
  WORKFLOW,
  ...MODULES,
  README,
  ...readdirSync(fileURLToPath(new URL('.', import.meta.url)))
    .filter((f) => f.endsWith('.mjs'))
    .map((f) => fileURLToPath(new URL(f, import.meta.url))),
];

// Invoked HERE, at module scope, which is the edit the shape above has to survive. A path declared below the
// closure fails this line with `ReferenceError: Cannot access '...' before initialization`.
const CAP_SOURCES = capSources();

// What the harness itself budgets, read from its source rather than restated here: the whole point is that two
// files stop disagreeing.
// The default behind an env knob, by the CONSTANT's name (`JOB_BUDGET_MS`) or by the env variable's
// (`REVIEW_JOB_BUDGET_MS`) — the README's table is keyed by the latter and the code by the former.
function budgetMinutes(envName) {
  const src = harnessSource();
  const m = new RegExp(`num\\(process\\.env\\.${envName}, (\\d+) \\* 60 \\* 1000\\)`).exec(src);
  assert.ok(m, `could not find ${envName}'s default in review.mjs — this test is reading the wrong shape`);
  return Number(m[1]);
}

function harnessDefaultMinutes(name) {
  const src = harnessSource();
  const m = new RegExp(`const ${name} = num\\(process\\.env\\.\\w+, (\\d+) \\* 60 \\* 1000\\)`).exec(src);
  assert.ok(m, `could not find ${name}'s default in review.mjs — this test is reading the wrong shape`);
  return Number(m[1]);
}

function readWorkflow(file = WORKFLOW) {
  const lines = readFileSync(file, 'utf8').split('\n');
  // Per job: a job starts at two spaces under `jobs:`, its keys sit at four, its steps at six. `review` is the
  // job every arithmetic check below is about; the others are read so their steps are bounded too.
  const jobs = {};
  let job = null;
  let inJobs = false;
  let inSteps = false;
  let current = null;
  for (const [i, line] of lines.entries()) {
    if (/^\s*#/.test(line) || !line.trim()) continue;
    if (/^jobs:$/.test(line)) { inJobs = true; continue; }
    if (!inJobs) continue;
    const jobStart = /^ {2}([\w-]+):$/.exec(line);
    if (jobStart) {
      job = jobs[jobStart[1]] = { name: jobStart[1], timeout: null, steps: [], line: i + 1 };
      inSteps = false;
      continue;
    }
    if (/^ {4}timeout-minutes: \d+$/.test(line) && !inSteps) {
      job.timeout = Number(line.trim().split(': ')[1]);
      continue;
    }
    if (/^ {4}steps:$/.test(line)) {
      inSteps = true;
      continue;
    }
    if (/^ {4}[\w-]+:/.test(line)) { inSteps = false; continue; }
    if (!inSteps) continue;
    const stepStart = /^ {6}- (\w[\w-]*): (.*)$/.exec(line);
    if (stepStart) {
      current = { line: i + 1, job: job.name };
      job.steps.push(current);
      current[stepStart[1]] = stepStart[2];
      continue;
    }
    const key = /^ {8}(\w[\w-]*):(.*)$/.exec(line);
    if (key) {
      assert.ok(current, `${file}:${i + 1}: a step key before any step — the reader has lost the shape`);
      current[key[1]] = key[2].trim();
      continue;
    }
    // Deeper lines belong to a `with:`/`env:`/`run: |` block, and a multi-line `if: >-` continues at any depth.
    // Neither changes an answer here, but an unindented line inside `steps:` means the file is not the shape assumed.
    assert.ok(/^ {10,}/.test(line) || /^ {6,}[^-]/.test(line), `${file}:${i + 1}: unrecognised line inside steps: ${line}`);
  }
  const review = jobs.review;
  assert.ok(review, 'no `review` job found');
  assert.ok(review.timeout, 'no job-level timeout-minutes found on the review job');
  assert.ok(review.steps.length >= 5, `only ${review.steps.length} steps parsed — the reader is not seeing the file`);
  return { jobTimeout: review.timeout, steps: review.steps, jobs };
}

// The text of one job, for the checks that read `with:` blocks the reader above does not model.
function jobText(name, file = WORKFLOW) {
  const text = readFileSync(file, 'utf8');
  const start = text.indexOf(`\n  ${name}:\n`);
  assert.ok(start !== -1, `no job named ${name}`);
  const next = text.slice(start + 1).search(/\n  [\w-]+:\n/);
  return next === -1 ? text.slice(start) : text.slice(start, start + 1 + next);
}

// A step's cap, with the inline comment that usually follows it. Strict on purpose: a value this cannot parse is
// an error, not a zero — the sums below are the whole point, and `Number('6   # ...')` is NaN, which compares
// false against every bound and would have made this file pass by saying nothing.
const minutes = (step) => {
  const raw = String(step['timeout-minutes'] ?? '');
  const m = /^(\d+)\s*(?:#.*)?$/.exec(raw);
  assert.ok(m, `${step.name || step.uses}: could not read a timeout from ${JSON.stringify(raw)}`);
  return Number(m[1]);
};

const named = (steps, fragment) => steps.filter((s) => (s.name || s.uses || '').includes(fragment));
const only = (steps, fragment) => {
  const found = named(steps, fragment);
  assert.equal(found.length, 1, `expected exactly one step matching ${JSON.stringify(fragment)}, found ${found.length}`);
  return found[0];
};

test('every step in the review job is bounded', () => {
  const { steps } = readWorkflow();
  const uncapped = steps.filter((s) => !s.hasOwnProperty('timeout-minutes')).map((s) => s.name || s.uses);
  assert.deepEqual(uncapped, [], 'a step with no timeout can burn the job cap, and a job cancelled by its own cap posts nothing');
});

test('the step caps fit inside the job cap with slack', () => {
  const { jobTimeout, steps } = readWorkflow();
  // The two notes are mutually exclusive (asserted below), so only the longer of them can ever run.
  const notes = named(steps, 'Say on the PR');
  const others = steps.filter((s) => !notes.includes(s));
  const sum = others.reduce((n, s) => n + minutes(s), 0) + Math.max(...notes.map(minutes));
  // Slack is for what the caps do not cover: per-step startup, the cache restore, the runner's own bookkeeping.
  // At 38 the sum was 37 and the worst path landed on 38:00 exactly, which is how this test came to exist.
  assert.ok(sum + 4 <= jobTimeout, `step caps sum to ${sum} against a job cap of ${jobTimeout}: the job timeout can bind, and it posts nothing when it does`);
});

test("the review step's cap is looser than the harness's own budget", () => {
  const { jobTimeout, steps } = readWorkflow();
  const review = only(steps, 'Run Claude review');
  const cap = minutes(review);
  const budget = harnessDefaultMinutes('JOB_BUDGET_MS');
  // review.mjs measures its budget from before the model lookup, and the reconcile phase that follows it is
  // deliberately unclocked (up to MAX_INLINE posts plus a resolve and a reply per closed thread). If this cap is
  // the tighter of the two, the step is killed mid-write — and a killed step explains nothing on the PR.
  // The cap must cover the model passes AND the write phase's network allowance, both read from the harness. The
  // margin was a bare `+ 4` chosen to stand for "reconcile needs some time" — now that the harness states that
  // number, the check reads it instead of restating it.
  const reconcile = budgetMinutes('REVIEW_RECONCILE_NETWORK_MS');
  assert.ok(
    cap >= budget + reconcile + 1,
    `the review step's ${cap} min must cover ${budget} of model passes plus ${reconcile} of write-phase network`,
  );
  assert.ok(cap < jobTimeout, 'the review step must fail on its own cap before the job is cancelled on the job cap');
});

test('the two failure notes cover the failures the harness cannot report itself', () => {
  const { steps } = readWorkflow();
  const setupNote = only(steps, 'harness did not run');
  const killedNote = only(steps, 'failed without explaining itself');

  for (const note of [setupNote, killedNote]) {
    // `always()` and `cancelled()` would also fire when a newer push cancels this run through
    // `concurrency: cancel-in-progress`, posting "the reviewer did not run" on a PR whose review is already
    // running again. `failure()` is what keeps these notes about failures.
    assert.match(note.if, /^failure\(\)/, `${note.name}: must be gated on failure()`);
    assert.equal(/always\(\)|cancelled\(\)/.test(note.if), false, `${note.name}: would fire on a superseded run`);
  }
  // Exclusive: exactly one of them can run, which is what lets the cap arithmetic count one.
  assert.match(setupNote.if, /steps\.review\.outcome != 'failure'/);
  assert.match(setupNote.if, /steps\.harness\.outcome == 'success'/, 'the note runs the harness, so it depends on the harness checkout');
  assert.match(killedNote.if, /steps\.review\.outcome == 'failure'/);
  // And the killed-note must not overwrite an explanation review.mjs already posted: they share a heading, so
  // the second write replaces the first and would trade the real error for a generic one.
  assert.match(killedNote.if, /steps\.review\.outputs\.explained != 'true'/);
  // And its text may not name a cause it cannot know. The gate fires on "the step failed and nothing was
  // written", which is two cases — killed before any handler ran, or a handler whose write was refused — and
  // asserting the first points a maintainer at the wrong knob when it was the second.
  const killedText = readFileSync(WORKFLOW, 'utf8').slice(readFileSync(WORKFLOW, 'utf8').indexOf('failed without explaining itself'));
  const run = killedText.slice(killedText.indexOf('--setup-failed'), killedText.indexOf('\n', killedText.indexOf('--setup-failed')));
  assert.match(run, /either|or/, 'the note asserts one cause when the gate cannot tell two apart');
  assert.match(harnessSource(), /appendFileSync\(out, 'explained=true/, 'nothing in the harness writes the output that gate reads');
  // And it is written only from the REVIEW step's own path. `--setup-failed` runs in these note steps, where an
  // output named `explained` is read by nobody — writing it there looked like part of the gate and was not.
  const harness = harnessSource();
  // Comments stripped first: the paragraph explaining WHY this call is absent names the call, and an assertion
  // that reads prose is defeated by the prose — the same trap as a check satisfied by its own comment, mirrored.
  const setupMode = harness
    .slice(harness.indexOf('async function reportSetupFailure'), harness.indexOf('async function runReview'))
    .replace(/\/\/.*$/gm, '');
  assert.equal(/recordExplainedOnPr\(\)/.test(setupMode), false, 'the note-only mode writes an output nothing reads');
});

test('every step in every job is bounded', () => {
  const { jobs } = readWorkflow();
  for (const job of Object.values(jobs)) {
    assert.ok(job.timeout, `${job.name}: no job-level timeout-minutes`);
    const uncapped = job.steps.filter((s) => !s.hasOwnProperty('timeout-minutes')).map((s) => s.name || s.uses);
    assert.deepEqual(uncapped, [], `${job.name}: a step with no timeout can burn the job cap`);
  }
});

test('the job that holds the secrets executes only the base branch\'s code', () => {
  // Under `pull_request` the workflow file, the harness and the lockfile all came from the pull request head, so
  // anyone who could push a branch could read both secrets by editing any of them. Now the event is
  // `pull_request_target` (the base branch's workflow file runs), the harness is checked out from the base branch
  // into `harness/` and is the only code the job runs, and the pull request's tree is a second checkout the agent
  // reads. Every one of those is a line in this file, and every one of them can drift back.
  const text = readFileSync(WORKFLOW, 'utf8');
  assert.match(text, /^on:\n  pull_request_target:/m, 'the event must be pull_request_target, or the pull request supplies this file');
  assert.equal(/^\s+pull_request:\s*$/m.test(text), false, 'a pull_request trigger would run the pull request\'s copy of this file');
  const review = jobText('review');
  assert.match(review, /environment: reviewer/, 'the secrets are scoped to the reviewer environment');
  const harness = /- name: Checkout the harness from the base branch[\s\S]*?(?=\n {6}- name:)/.exec(review)?.[0];
  assert.ok(harness, 'no harness checkout step');
  assert.match(harness, /ref: \$\{\{ github\.event\.pull_request\.base\.ref \}\}/, 'the harness must come from the base branch');
  assert.match(harness, /path: harness/);
  const pr = /- name: Checkout PR head[\s\S]*?(?=\n {6}- name:)/.exec(review)?.[0];
  assert.match(pr, /ref: \$\{\{ github\.event\.pull_request\.head\.sha \}\}/);
  assert.match(pr, /path: pr/);
  assert.match(pr, /persist-credentials: false/);
  // Every node the job runs is the harness's; the agent is pointed at the other tree.
  for (const run of review.matchAll(/^\s+run: (node .*)$/gm)) assert.match(run[1], /^node harness\//, `${run[1]}: runs code from outside the trusted checkout`);
  assert.match(review, /working-directory: harness\/\.github\/claude\/reviewer/);
  assert.match(review, /REVIEW_CHECKOUT: \$\{\{ github\.workspace \}\}\/pr/, 'the agent must be pointed at the pull request tree');
  assert.equal(/node --test/.test(review.replace(/^\s*#.*$/gm, '')), false, 'the review job must not run tests from the pull request tree');
});

test('every action in the reviewer workflow is pinned to a commit SHA, with its version beside it', () => {
  // A mutable tag (`@v5`) lets the action's maintainer — or whoever ends up holding the tag — swap the code that
  // runs inside the job with the secrets. A 40-hex commit cannot move. The trailing `# vX.Y.Z` is for the human
  // who bumps it next, and for the reviewer reading a diff of the pin.
  //
  // Scope: THIS workflow only. The harness is portable — the same suite runs in every repository that carries it —
  // so it does not assert on the repository's other workflows; pinning those is that repository's own change.
  // Limit: this is a shape check. Nothing local can verify that the commit IS the tag in the comment (that takes
  // the upstream repository's refs); a bump that edits one and not the other passes here and is caught in review.
  const text = readFileSync(WORKFLOW, 'utf8');
  // Both step forms: `uses:` after a `name:`, and the bare `- uses:` step, which has no name key to hide behind.
  const uses = [...text.matchAll(/^\s+(?:- )?uses: (\S+)(.*)$/gm)];
  assert.ok(uses.length >= 2, 'no uses: lines found in the workflow');
  for (const [line, ref, rest] of uses) {
    if (ref.startsWith('./')) continue; // a local action is this repository's own code, pinned by the commit under review
    // owner/repo[/subdirectory...]@sha — subdirectory actions (`gradle/actions/setup-gradle@…`) are one `uses:` too.
    assert.match(ref, /^[\w.-]+\/[\w.-]+(?:\/[\w.-]+)*@[0-9a-f]{40}$/, `${line.trim()}: not pinned to a commit SHA`);
    assert.match(rest, /^\s+# v\d+(?:\.\d+)*(?:-[\w.]+)?\s*$/, `${line.trim()}: no version comment beside the pin`);
  }
});

test('the job that runs pull request code holds no secret', () => {
  // The other half of `pull_request_target`: the pull request's own harness tests execute its code, so that job
  // gets no secret, no environment, and a read-only token it does not persist.
  const tests = jobText('harness-tests');
  assert.equal(/secrets\./.test(tests), false, 'a secret reference in the job that runs pull request code');
  assert.equal(/environment:/.test(tests), false, 'the environment would hand it the secrets');
  assert.match(tests, /permissions:\n {6}contents: read\n/, 'the token must be read-only');
  assert.match(tests, /persist-credentials: false/);
  assert.match(tests, /node --test test\//, 'the pull request\'s tests must run somewhere');
  // And it is gated on the pull request touching the harness, so an app change does not pay for it.
  assert.match(tests, /steps\.touches\.outputs\.harness == 'true'/);
});

test('the budget numbers written in prose are the real ones', () => {
  // The drift this catches has happened twice: a cap moved and the comments explaining it did not, so the only
  // place the arithmetic is written down said 25 while the file said 38 — and a maintainer reasoning from a
  // comment gets the wrong bound. The convention is the point: when prose names a cap, it writes it as "the
  // job's N" or "the review step's N", and this test reads both files and checks every one of them.
  const { jobTimeout, steps } = readWorkflow();
  const reviewCap = minutes(only(steps, 'Run Claude review'));
  // Every file that can carry a cap figure, and that includes `github.mjs` and this suite: a comment there said
  // "the job's 48" while neither check read the file, which is the drift these exist for, one file over.
  const sources = capSources().map((f) => readFileSync(f, 'utf8'));
  const claims = { "the job's": jobTimeout, "the review step's": reviewCap };

  let checked = 0;
  for (const src of sources) {
    for (const [phrase, expected] of Object.entries(claims)) {
      for (const m of src.matchAll(new RegExp(`${phrase.replace("'", "['’]")} (\\d+)`, 'g'))) {
        checked++;
        assert.equal(Number(m[1]), expected, `a comment says "${phrase} ${m[1]}" but it is ${expected}`);
      }
    }
  }
  assert.ok(checked >= 3, `only ${checked} prose figures found — the convention has been written around, so this test is no longer reading anything`);
});
test("the knob table's budgets are the code's budgets", () => {
  // The README is the document a maintainer reads BEFORE changing a budget, which makes it the worst place for a
  // stale number — and the prose check above reads only the workflow and review.mjs, so this table was the one
  // spot where these figures could drift unnoticed. Same failure the check exists to prevent, one file over.
  const readme = readFileSync(README, 'utf8');
  const rows = [
    ['REVIEW_DEADLINE_MS', 'DEADLINE_MS'],
    ['REVIEW_JOB_BUDGET_MS', 'JOB_BUDGET_MS'],
    ['REVIEW_VERIFY_BUDGET_MS', 'VERIFY_BUDGET_MS'],
  ];
  for (const [envName] of rows) {
    const row = new RegExp(`\\| \`${envName}\` \\| (\\d+) min`).exec(readme);
    assert.ok(row, `the knob table has no row for ${envName}`);
    assert.equal(Number(row[1]), budgetMinutes(envName), `the README says ${envName} is ${row[1]} min`);
  }
  // The verification cap, which the README now states in prose ("up to 20 still-open threads"). A number written
  // in a document is a number that can drift: this is the same check, one sentence over.
  const cap = /judges up to (\d+) still-open threads/.exec(readme);
  assert.ok(cap, 'the README no longer says how many threads a round judges');
  const capInCode = /const MAX_VERIFY_THREADS = (\d+);/.exec(harnessSource());
  assert.ok(capInCode, 'could not find MAX_VERIFY_THREADS in review.mjs');
  assert.equal(Number(cap[1]), Number(capInCode[1]), `the README says ${cap[1]} threads, the code says ${capInCode[1]}`);

  // And the turn limit, which is written in two places at once: the code's default and the workflow's override.
  const turns = /\| `REVIEW_MAX_TURNS` \| (\d+) in code, (\d+) in the workflow \|/.exec(readme);
  assert.ok(turns, 'the knob table has no REVIEW_MAX_TURNS row');
  const codeDefault = /num\(process\.env\.REVIEW_MAX_TURNS, (\d+)\)/.exec(harnessSource());
  assert.ok(codeDefault, "could not find REVIEW_MAX_TURNS's default in review.mjs");
  assert.equal(Number(turns[1]), Number(codeDefault[1]), 'the README disagrees with the code about the turn limit');
  const inWorkflow = /REVIEW_MAX_TURNS: '(\d+)'/.exec(readFileSync(WORKFLOW, 'utf8'));
  assert.ok(inWorkflow, 'the workflow no longer sets REVIEW_MAX_TURNS');
  assert.equal(Number(turns[2]), Number(inWorkflow[1]), 'the README disagrees with the workflow about the turn limit');
});

test('a cap claimed in prose is written where the drift check can read it', () => {
  // Fourth version of this check, and the first that is not a list of phrasings. Matching known wordings —
  // "capped at N minutes", then "job cap of N" — meant each new way of writing the same claim was invisible
  // until it drifted: "its 24-minute step timeout" was, and a stale "a 14-minute timeout" had been sitting in
  // review.mjs since the cap was 14. So the claim is what is detected now: a minute figure on a line that also
  // says cap or timeout. Either write it as `the job's N` / `the review step's N`, which the check above
  // verifies, or do not put the number in prose at all.
  const exempt = [
    /^\s*timeout-minutes:/,          // the YAML key IS the source of truth
    /^\s*\|/,                        // the README's knob table, pinned by the test above
    /~\s*\d/,                        // "~1 min of setup" is an estimate of duration, not a claim about a cap
  ];
  const claim = /\b\d+[- ]min(?:ute)?s?\b/i;
  const aboutACap = /\b(cap|capped|timeout)\b/i;
  const canonical = /the (?:job|review step)'s \d+/;

  const offenders = [];
  for (const file of capSources()) {
    const name = file.split('/').slice(-1)[0];
    // This file is exempt from ITS OWN offender scan, and only from that one: its comment necessarily quotes the
    // phrasings it refuses, and a check that cannot describe what it refuses is worse than one with an exemption
    // it names. The canonical-number check above still reads it, so a figure written here in the checked form
    // must still be the real one.
    if (name === 'workflow.test.mjs') continue;
    for (const [i, line] of readFileSync(file, 'utf8').split('\n').entries()) {
      if (exempt.some((re) => re.test(line))) continue;
      if (claim.test(line) && aboutACap.test(line) && !canonical.test(line)) {
        offenders.push(`${name}:${i + 1}: ${line.trim().slice(0, 100)}`);
      }
    }
  }
  assert.deepEqual(offenders, [], `write a cap as \`the job's N\` / \`the review step's N\`, or leave the number out:\n${offenders.join('\n')}`);
});
test('the install step runs the smoke check, and the smoke check runs the binary', () => {
  // `typeof m.query === 'function'` proved only that JavaScript installed. What the review step needs is the native
  // CLI for this runner, which a lockfile written on another OS can leave out with every JS import still green.
  // The mini-reader keeps a `run: |` block as its marker, so the command is read from the workflow's text.
  assert.match(readFileSync(WORKFLOW, 'utf8'), /^\s+node smoke\.mjs\s*$/m, 'the install step no longer runs smoke.mjs');
  const smoke = readFileSync(fileURLToPath(new URL('../smoke.mjs', import.meta.url)), 'utf8');
  assert.match(smoke, /spawnSync\(bin, \['--version'\]/, 'smoke.mjs does not run the CLI binary');
  assert.match(smoke, /constants\.X_OK/, 'smoke.mjs does not check the execute bit');
});

test('the directory is self-contained: its own .gitignore covers what npm ci installs', () => {
  // The rule lived in the repository root for a while, which is the one file the porting story ("copy this
  // directory and the workflow") does not copy — so the first `npm ci` in the next repository, which the README
  // tells you to run, left an unignored `node_modules` under it.
  const ignore = readFileSync(fileURLToPath(new URL('../.gitignore', import.meta.url)), 'utf8');
  assert.ok(ignore.split('\n').some((l) => l.trim() === 'node_modules/' || l.trim() === 'node_modules'), 'the module .gitignore does not ignore node_modules/');
});

test('the public README keeps no secret coordinates', () => {
  // This repository is public. That the resolve PAT has a backup belongs in the README; the parameter name, the
  // account profile and the region do not — none is a credential, and all three are reconnaissance for anyone who
  // later obtains credentials for that account. The rest of this file is careful about exactly that class.
  const readme = readFileSync(README, 'utf8');
  for (const leak of [/\/github\/review-resolve-pat/, /profile `?bookplayer`?/, /us-east-1/]) {
    assert.equal(leak.test(readme), false, `the README publishes ${leak} in a public repository`);
  }
  assert.match(readme, /backup copy in SSM/, 'the fact that a backup exists should stay');
  // And the corpus helper is usable where it is now called: at module scope, above.
  assert.ok(CAP_SOURCES.length >= 5 && CAP_SOURCES.every((f) => typeof f === 'string' && f.length));
});
