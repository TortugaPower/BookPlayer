// A comment that names something the code does not have.
//
// This harness is heavily commented on purpose — the reasoning is the part that is expensive to reconstruct — and
// that makes a wrong comment expensive too: it is the entry point a maintainer reads before touching the code. The
// review loop has now found five of them, three in the last three rounds: a row saying "answered" when nobody had
// answered, a record field advertising a lookup it never did, two budget figures left behind when a cap moved, a
// duplicated block still describing the previous behaviour, and `See \`disambiguate\`` pointing at a function that
// does not exist under any name.
//
// The last one is the sharpest form and the only one a machine can see cheaply: a comment naming an identifier
// that is nowhere in the code. So it is checked here. The bar is deliberately low — one regex over backticked
// words — and the point is the ALLOWLIST below: when you write `foo` in a comment and `foo` is not in the code,
// you must either fix the name or write down why it is not code. "The function is called something else now" is
// not a reason anyone would write, which is exactly how the check earns its place.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('..', import.meta.url));

// Named in a comment, deliberately not code. Each one needs a reason, and the reason is the review.
const NOT_CODE = {
  // Code that USED to exist, named so the history is legible.
  planClosures: 'deleted: the resemblance-based closer, named where its removal is explained',
  // Code that USED to exist, named so the history is legible.
  verifiedIds: 'deleted: a guard a mutation sweep proved redundant, named where the seam it left is explained',
  eligibleIds: 'deleted alongside verifiedIds; the test comment explains what the sweep showed',
  resolvedBy: 'a field from an earlier marker design, named where the current rule is contrasted with it',
  // Names owned by something other than this codebase.
  direction: "a GitHub REST query parameter, on an endpoint that ignores it — that is the point of the sentence",
  pushd: 'a shell builtin the tool gate refuses, named in the list of what it refuses',
  realpath: 'the POSIX call, named where the harness explains what it resolves paths with',
  onStop: 'an Android lifecycle method, named in the example of two findings that differ by one word',
  lastIndex: 'the RegExp property a global pattern keeps between calls, named where a fresh RegExp is built to avoid it',
};

// Calls named in comments that belong to somebody else's vocabulary.
const NOT_OURS = {
  'Number': 'the JavaScript builtin',
  'always': "a GitHub Actions expression function, named where the workflow's conditions are explained",
  'cancelled': 'a GitHub Actions expression function, named for the same reason',
  'failure': 'a GitHub Actions expression function, named for the same reason',
};

// This file is not in its own corpus: its allowlist KEYS are identifiers, so scanning it would let every entry
// justify itself — `planClosures` is "in the code" the moment it is written down here.
const SELF = 'comments.test.mjs';
// Every module in the directory, then every test but this one. Listing the modules by name was fine while there
// were two; the split into seams made the list the thing most likely to be stale.
const MODULES = () => readdirSync(DIR).filter((f) => f.endsWith('.mjs')).sort();
const sourceFiles = () =>
  [...MODULES(), ...readdirSync(`${DIR}test`).filter((f) => f.endsWith('.mjs') && f !== SELF).map((f) => `test/${f}`)];

// The code a comment in this directory may legitimately name is not only JavaScript: these tests reason about
// the harness's own workflow, and `concurrency` or `timeout-minutes` are as real as any function here. It is part
// of the corpus a name resolves against, with its own comment syntax stripped.
const NEIGHBOURS = [
  ['../../../workflows/claude-review.yml', /^\s*#.*$/gm],
];
const neighbourCode = () =>
  NEIGHBOURS.map(([rel, comments]) => readFileSync(fileURLToPath(new URL(rel, import.meta.url)), 'utf8').replace(comments, '')).join('\n');

const identifiersInComments = (text) => {
  const found = new Set();
  for (const line of text.split('\n')) {
    const comment = /^\s*(?:\/\/|#|\*)(.*)$/.exec(line);
    if (!comment) continue;
    for (const token of comment[1].matchAll(/`([^`]+)`/g)) {
      // Only things shaped like an identifier: no dots, slashes, spaces or punctuation, and long enough that a
      // word like `id` or `fp` does not drag prose into this.
      if (/^[A-Za-z_][A-Za-z0-9_]{3,}$/.test(token[1])) found.add(token[1]);
    }
  }
  return found;
};

test('every identifier a comment names exists in the code', () => {
  const files = sourceFiles();
  const sources = files.map((f) => readFileSync(`${DIR}${f}`, 'utf8'));
  // Comments stripped: a name that appears ONLY in comments is exactly what this is looking for, and one comment
  // agreeing with another is not evidence of anything.
  const code = [...sources.map((s) => s.replace(/\/\/.*$/gm, '')), neighbourCode()].join('\n');

  const unresolved = [];
  for (const [file, text] of files.map((f, i) => [f, sources[i]])) {
    for (const name of identifiersInComments(text)) {
      if (NOT_CODE[name]) continue;
      if (new RegExp(`\\b${name}\\b`).test(code)) continue;
      unresolved.push(`${file}: \`${name}\` is named in a comment and is nowhere in the code`);
    }
  }
  assert.deepEqual(unresolved, [], `${unresolved.length} comment(s) name something that does not exist:\n${unresolved.join('\n')}`);
});

test('a comment that names a CALL names a function that exists', () => {
  // The sharper half, and the one that would have caught `main()` — which survived the plain-identifier check for
  // twelve comments because "main" also exists in the code as the string `BASE_REF || 'main'` and as a branch name
  // in both workflows. A backticked `name()` is a claim about a FUNCTION, so it is checked against declarations
  // rather than against any occurrence of the word.
  const files = sourceFiles();
  const sources = files.map((f) => readFileSync(`${DIR}${f}`, 'utf8'));
  const code = sources.map((s) => s.replace(/\/\/.*$/gm, '')).join('\n');
  const declared = new Set([
    ...[...code.matchAll(/\b(?:export\s+)?(?:async\s+)?function\s+(\w+)/g)].map((m) => m[1]),
    ...[...code.matchAll(/\b(?:const|let|var)\s+(\w+)\s*=/g)].map((m) => m[1]),
  ]);

  const unresolved = [];
  for (const [file, text] of files.map((f, i) => [f, sources[i]])) {
    for (const line of text.split('\n')) {
      const comment = /^\s*(?:\/\/|#|\*)(.*)$/.exec(line);
      if (!comment) continue;
      for (const call of comment[1].matchAll(/`(\w+)\(\)`/g)) {
        if (NOT_OURS[call[1]] || declared.has(call[1])) continue;
        unresolved.push(`${file}: \`${call[1]}()\` is named in a comment and no function by that name is declared`);
      }
    }
  }
  assert.deepEqual(unresolved, [], `${unresolved.length} comment(s) name a function that does not exist:\n${unresolved.join('\n')}`);
});

test('the allowlist is a list of decisions, not a drawer', () => {
  // An entry that stops being needed has to go, or the list becomes the place names go to be forgotten — which
  // is the failure this file is about, one level up.
  const files = sourceFiles();
  const sources = files.map((f) => readFileSync(`${DIR}${f}`, 'utf8'));
  const named = new Set(sources.flatMap((s) => [...identifiersInComments(s)]));
  const code = [...sources.map((s) => s.replace(/\/\/.*$/gm, '')), neighbourCode()].join('\n');

  for (const [name, reason] of Object.entries(NOT_CODE)) {
    assert.ok(reason.length > 20, `${name}: an allowlist entry needs a reason worth reading`);
    assert.ok(named.has(name), `${name} is allowlisted but no comment names it any more — delete the entry`);
    assert.equal(new RegExp(`\\b${name}\\b`).test(code), false, `${name} is allowlisted as "not code" but the code has it now — delete the entry`);
  }
});

// The lines that are inside a `console.warn/log/error(` call, the call tracked across lines by paren depth. The
// first version of the two checks below required the `console.` and the interpolation to share a line, which is
// how the second site in `keyFindings` stayed unbounded while the first was fixed and the test passed. The
// tracker errs toward staying inside a call: more lines checked, never fewer.
function* consoleLines(src) {
  let depth = 0;
  for (const [i, line] of src.split('\n').entries()) {
    const opens = (line.match(/\(/g) || []).length;
    const closes = (line.match(/\)/g) || []).length;
    const starts = /console\.(warn|log|error)\(/.test(line);
    if (!starts && depth <= 0) continue;
    if (starts && depth <= 0) depth = opens - closes;
    else depth += opens - closes;
    yield [i + 1, line];
  }
}

// Every `${...}` on a line, the expression read to ITS closing brace rather than to the first `}` — an object
// literal or a nested template inside one would otherwise cut it short.
function interpolations(line) {
  const out = [];
  for (let at = line.indexOf('${'); at !== -1; at = line.indexOf('${', at + 2)) {
    let depth = 0;
    for (let i = at + 1; i < line.length; i++) {
      if (line[i] === '{') depth++;
      else if (line[i] === '}' && --depth === 0) { out.push(line.slice(at + 2, i)); break; }
    }
  }
  return out;
}

// `redact(` at the start and ITS `)` as the last character: `redact(a) + e.message` is not wrapped, and neither
// is `redact(a), e.message`. The name is the one both files use — `github.mjs` receives the function under it.
function wrappedInRedact(expr) {
  if (!expr.startsWith('redact(')) return false;
  let depth = 0;
  for (let i = 'redact'.length; i < expr.length; i++) {
    if (expr[i] === '(') depth++;
    else if (expr[i] === ')' && --depth === 0) return i === expr.length - 1;
  }
  return false;
}

// The text between a brace at `open` and its match, `{}`/`()`/`[]` counted together.
function balanced(text, open) {
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if ('{(['.includes(text[i])) depth++;
    else if ('})]'.includes(text[i]) && --depth === 0) return text.slice(open + 1, i);
  }
  return null;
}
// Top-level segments of an object literal or destructuring pattern.
const segments = (inner) => {
  const out = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < inner.length; i++) {
    if ('{(['.includes(inner[i])) depth++;
    else if ('})]'.includes(inner[i])) depth--;
    else if (inner[i] === ',' && depth === 0) { out.push(inner.slice(start, i)); start = i + 1; }
  }
  out.push(inner.slice(start));
  return out.map((s) => s.trim()).filter(Boolean);
};
const keyOf = (segment) => /^(?:\.\.\.)?([A-Za-z_$][\w$]*)/.exec(segment)?.[1] ?? null;

test('an option a caller passes is one the function takes', () => {
  // `actionByFp({ currentByFp, unpostable: [] })` passed an option the function does not have — its name is
  // `unpostableFps` — so the default applied and the test meant something other than what it said. The same
  // class as a comment naming code that is not there, one level down: a name that looks bound and is not. For
  // every exported function whose first parameter is an options object, every call that spells its options as
  // a literal may use only the names the pattern declares. A spread or a computed key is not checked.
  const src = MODULES().map((f) => readFileSync(`${DIR}${f}`, 'utf8')).join('\n');
  const declared = new Map();
  for (const m of src.matchAll(/^export (?:async )?function (\w+)\(\{/gm)) {
    const pattern = balanced(src, m.index + m[0].length - 1);
    declared.set(m[1], new Set(segments(pattern).map(keyOf).filter(Boolean)));
  }
  assert.ok(declared.size >= 5, `only ${declared.size} option-object functions found; the signature regex has drifted`);

  const offenders = [];
  for (const file of sourceFiles()) {
    const text = readFileSync(`${DIR}${file}`, 'utf8');
    for (const [name, keys] of declared) {
      for (const call of text.matchAll(new RegExp(`\\b${name}\\(\\{`, 'g'))) {
        const literal = balanced(text, call.index + call[0].length - 1);
        if (literal === null) continue;
        for (const seg of segments(literal)) {
          if (seg.startsWith('...') || seg.startsWith('[')) continue;
          const key = keyOf(seg);
          if (key && !keys.has(key)) offenders.push(`${file}: ${name}({ ${key} }) — the function takes { ${[...keys].join(', ')} }`);
        }
      }
    }
  }
  assert.deepEqual(offenders, [], `${offenders.length} call(s) pass an option the function ignores:\n${offenders.join('\n')}`);
});

test('nothing reaches the log with an upstream message still in it', () => {
  // The rule this file's subject states about itself: "every string that leaves this process goes through
  // `redact`, log lines included". It was applied by hand — twice, by regex — and both times the regex was the
  // boundary rather than the rule: the first sweep matched `${e.message}` and missed `${msg}`, the second missed
  // a `reason` whose own third branch embedded an error. A public repository's run log is public, and `rest()`
  // deliberately embeds the whole upstream response body in its error messages.
  //
  // So it is checked, with no exemption for "this one is already safe": `redact` is idempotent, so wrapping a
  // value that was built from redacted parts costs nothing, and a rule with exemptions is the thing that let two
  // sweeps miss three sites. Anything interpolated into a console call whose NAME says it carries an error is
  // wrapped at the interpolation, full stop.
  //
  // Two more holes this check itself had, both found by the reviewer reading the code rather than by the test:
  // it read only `review.mjs`, while `github.mjs` had two warnings quoting a thrown error; and it matched only a
  // plain `${x.message}`, so `${e.name || e.message}` — the exact shape those two warnings used — was invisible
  // to it. The rule is stated as absolute, so the check covers both files and every interpolation, and asks that
  // the WHOLE expression be the argument of `redact(...)`.
  const carriesError = /\b(message|msg|stack|reason)\b/i;
  const offenders = [];
  for (const file of MODULES()) {
    for (const [lineNo, line] of consoleLines(readFileSync(`${DIR}${file}`, 'utf8'))) {
      for (const expr of interpolations(line)) {
        if (!carriesError.test(expr)) continue;
        if (wrappedInRedact(expr)) continue;
        offenders.push(`${file}:${lineNo}: \${${expr}} reaches the log unredacted — ${line.trim().slice(0, 80)}`);
      }
    }
  }
  assert.deepEqual(offenders, [], `wrap these in redact():\n${offenders.join('\n')}`);
});

test('the log checks see what they claim to', () => {
  // The helpers above ARE the boundary of the two log checks, so each blind spot they closed is pinned: a check
  // that quietly stops seeing a shape passes vacuously, which is how both earlier versions failed.
  assert.deepEqual([...consoleLines('a\nconsole.warn(`x`,\n  y\n);\nz')].map(([n]) => n), [2, 3, 4]);
  assert.deepEqual(interpolations('`${e.name || e.message} and ${redact({ a: 1 }.b)}`'), ['e.name || e.message', 'redact({ a: 1 }.b)']);
  assert.equal(wrappedInRedact('redact(e.message)'), true);
  assert.equal(wrappedInRedact('redact(e.message || String(e))'), true);
  assert.equal(wrappedInRedact('redact(a) + e.message'), false);
  assert.equal(wrappedInRedact('e.name || redact(e.message)'), false);
});

test("model-authored text reaches the log only through boundedDump", () => {
  // `boundedDump` is the one wrapper that does all three things this needs: it redacts, it bounds, and it breaks
  // a leading `::` so model text cannot forge a workflow command. The redaction check above cannot see this
  // class — it keys on names like `message` and `reason`, and `f.same_as` is neither — and a public run log is
  // where an unbounded finding, or a `same_as` filled with prose quoted from the diff, would land verbatim.
  //
  // The DRY_RUN print goes through it too, and loses nothing: the default bound is thousands of characters, far
  // past any real finding, and redaction only touches secret shapes.
  const src = MODULES().map((f) => readFileSync(`${DIR}${f}`, 'utf8')).join('\n');
  // Keyed on the FIELD, not the object it hangs off. `[fvd].file` was the first spelling and
  // `claimedThread.path` was the second — the same text under another variable — so the object name proved to be
  // the wrong half to match on. A GitHub-derived path caught by this loses nothing: `boundedDump` is idempotent
  // on short strings.
  const modelText = /\.(file|comment|same_as|evidence|text|summary|path)\b/;
  // Lines come from `consoleLines`, which tracks a call across lines — see its comment for the site that taught it.
  const offenders = [];
  for (const [lineNo, line] of consoleLines(src)) {
    for (const expr of interpolations(line)) {
      if (!modelText.test(expr)) continue;
      if (/boundedDump\(/.test(expr)) continue;
      offenders.push(`line ${lineNo} of the joined modules: \${${expr}} — model text to the log without boundedDump`);
    }
  }
  assert.deepEqual(offenders, [], `wrap these in boundedDump():\n${offenders.join('\n')}`);
});
