// The sandbox: what the agent may run, read and see, and what may leave the process. The Bash grammar and its
// allowlists, the path rules and the two roots, the environment handed to the SDK, the write tokens withheld while
// it runs, and `redact` — the one boundary every string crosses on its way out. Pure, and unit-tested line by line.

import { existsSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { setLogRedactor } from './github.mjs';
import { REPO_SECRET_FILES, REPO_SECRET_SHAPES } from './repo.mjs';
import { PR_NUMBER } from './config.mjs';

// Failure dump of the agent's answer in the run log (head + tail). Extraction failures are visible in the first and
// last couple of KB; the full 20 KB is available with ACTIONS_STEP_DEBUG, since the log of a public repo is public
// and redact() does not know every secret shape (an app-specific password quoted from a diff, for instance).
const maxDumpChars = () => (process.env.ACTIONS_STEP_DEBUG === 'true' ? 20_000 : 4_000);

// Everything the model writes is posted to the PR, and everything it reads is PR-author-controlled, so
// scrub credential values and well-known key shapes at the post boundary regardless of how they got there.
// Captured at load AND at the start of every run: at load so a log line before `runReview` is covered, at run
// start because the values must be known BEFORE `withoutWriteTokens` deletes two of them from the environment —
// a lazy read during the agent's run would find nothing to redact. (And this module is shared across the
// scenarios a test process runs, each with its own key.)
let SECRET_VALUES = [];
export function captureSecretValues() {
  SECRET_VALUES = ['ANTHROPIC_API_KEY', 'GITHUB_TOKEN', 'REVIEW_RESOLVE_TOKEN']
    .map((k) => process.env[k])
    .filter((v) => v && v.length >= 8);
  return SECRET_VALUES.length;
}
captureSecretValues();

// Every string that leaves this process goes through here — log lines included, not only what is posted. A public
// repository's run log is public, and `rest()` embeds the whole upstream response body in its error message, so a
// warning that interpolates `e.message` raw is a hole in a boundary the rest of this file keeps. The rule is
// "everything", because "most of them" is not a rule anyone can check — and "everything" means `github.mjs` too:
// it has log lines of its own and cannot import this file, so it is handed this function below and withholds
// error messages until it has it. The test that checks the rule reads both files.
export function redact(text) {
  let out = String(text);
  for (const v of SECRET_VALUES) out = out.split(v).join('[redacted]');
  out = out
    .replace(/sk-ant-[A-Za-z0-9_-]{16,}/g, '[redacted]')
    .replace(/gh[pousr]_[A-Za-z0-9]{20,}/g, '[redacted]')
    .replace(/github_pat_[A-Za-z0-9_]{20,}/g, '[redacted]')
    .replace(/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g, '[redacted private key]');
  // The repository's own shapes last, from the one per-repository file (see repo.mjs).
  for (const { pattern, replacement } of REPO_SECRET_SHAPES) out = out.replace(pattern, replacement);
  return out;
}

// At module scope, not in `runReview`: the first GitHub call this process makes is before any budget is armed, and
// a warning from that call would otherwise be the one line that misses the boundary.
setLogRedactor(redact);

// PR title/body are quoted inside delimiter tags in the prompt; neutralise anything that could close them.
export const escapePrText = (s) => String(s).replace(/</g, '&lt;');

// For values interpolated into a double-quoted attribute: `<` alone would still let a `"` close the attribute.
export const escapeAttr = (s) => escapePrText(s).replace(/"/g, '&quot;');

// Model-authored text is posted next to our HTML-comment markers; make sure it can't contain one itself.
export const neutralizeMarkup = (s) => String(s).replace(/<!--/g, '&lt;!--');

// A path is PR-author text and these labels are rendered inside a Markdown table in our own comment: a backtick
// or a pipe in a filename would break the table, and `<!--` would smuggle a comment into it.
export const mdPath = (p) => neutralizeMarkup(String(p).replace(/[`|]/g, ''));

// Model-authored prose in a table cell: a `|` would end the column and a newline the row.
export const mdCell = (t) => neutralizeMarkup(String(t).replace(/\s+/g, ' ').replace(/\|/g, '\\|'));

// The single statement of the Bash rules: the system prompt tells the agent this, and canUseTool's denial repeats
// it. The two wordings had drifted — the prompt omitted `stat`, `file`, `du`, `pwd`, `echo`, `git ls-files` and
// `git rev-parse`, and never mentioned `<`, braces or `cd` — and every mismatch costs a turn on a denial whose
// message is the agent's first sight of the real rule.
export const BASH_RULES =
  'ONE simple command of plain words separated by spaces: git diff/log/show/blame/status/ls-files/rev-parse, cat, ' +
  'ls, head, tail, wc, grep, find, stat, file, du, pwd, echo. No quotes, no backslashes, no globs (`*?[`), no ' +
  '`$`/backticks/braces, no redirection or pipes, no `;`/`&&`, no `~` starting a word, no `cd`, and printable ' +
  'ASCII only. This is a grammar, not a filter: anything else is refused without interpretation, because a ' +
  'permission gate cannot reliably predict what bash would expand a cleverer command into. ' +
  'Flags are allowlisted per command, spelled in full: the ones a review needs are accepted and every other ' +
  'flag is refused, including abbreviations, anything that makes a walk follow symlinks (grep -R, find -L), ' +
  'anything that never returns (tail -f), and anything that takes its filenames from a file (--files0-from, ' +
  'file -f). For a pattern with ' +
  'spaces or a glob, use the Grep and Glob tools — they take the pattern as data and are allowed. Paths are ' +
  'relative to the checkout.';

// ---------- Tool permissions: the agent reads, nothing else ----------
// Everything it sees (diff, files, PR text) is PR-author-controlled, so Bash is limited to an allowlist of
// read-only commands and every other side-effecting tool is denied. A denial costs the agent one turn.
const READ_ONLY_TOOLS = new Set(['Read', 'Grep', 'Glob']);

const BASH_ALLOW = [
  /^git (-C \S+ )?(diff|log|show|blame|status|ls-files|rev-parse)(\s|$)/,
  /^(cat|ls|head|tail|wc|grep|find|stat|file|du|pwd|echo)(\s|$)/,
];

// Flags that let an otherwise read-only command write a file, or make a recursive walk follow symlinks (the
// realpath check covers named paths, not the traversal grep -R / find -L would do through a link). Scoped per
// command so e.g. `git blame -L 10,20` (a line range) stays allowed, and matched inside short-flag clusters (-Rn).
// `--output` writes. The `files0-from`/`files-from` family is worse in a subtler way: the flag's own argument is
// an in-root file, which passes every check, and the program then opens whatever paths that file's CONTENTS name.
// Verified: a committed list containing `/etc/passwd` made `file -f list.txt` report on /etc/passwd from inside
// the checkout. Confinement cannot follow indirection, so the flags are refused instead.
const DENY_FLAGS_ANY = /(^|\s)(--output(=|\s)|--files0?-from(=|\s)|-files0-from(\s|$))/;

const DENY_FLAGS_BY_COMMAND = {
  grep: /(^|\s)(-[A-Za-z]*R[A-Za-z]*|--dereference-recursive)(\s|$)/,
  find: /(^|\s)(-L|-H|-follow|-(exec|execdir|ok|okdir|delete|fprint0?|fprintf|fls))(\s|$)/,
  // Short clusters and long forms both, for every command that can walk a tree: the realpath check covers the
  // paths a command is *given*, not the ones a walk discovers through a symlink committed in the checkout.
  ls: /(^|\s)(-[A-Za-z]*L[A-Za-z]*|--dereference(-command-line(-symlink-to-dir)?)?)(\s|$)/,
  du: /(^|\s)(-[A-Za-z]*[LH][A-Za-z]*|--dereference(-args)?)(\s|$)/,
  // Not a read escape but a budget one: `tail -f` never returns, so the agent sits on it until the deadline and
  // the round degrades to the incomplete note having found nothing. Nothing in a review needs to follow a file.
  tail: /(^|\s)(-[A-Za-z]*[fF][A-Za-z]*|--follow(=\S*)?|--retry)(\s|$)/,
  // `file -f LIST` is the same indirection as --files-from, spelled shorter.
  file: /(^|\s)(-[A-Za-z]*f[A-Za-z]*|--files-from(=|\s))(\s|$)/,
};

function hasDeniedFlag(segment) {
  const command = segment.split(/\s+/)[0];
  const scoped = DENY_FLAGS_BY_COMMAND[command];
  return DENY_FLAGS_ANY.test(segment) || Boolean(scoped && scoped.test(segment));
}

const BASH_DENY_MESSAGE = `Bash is restricted to a read-only grammar: ${BASH_RULES}`;

export const BASH_DENY_MESSAGE_FOR_TEST = BASH_DENY_MESSAGE; // the agent's first sight of the rules, asserted alongside the prompts

// ---------------------------------------------------------------------------------------------------------------
// Why this is a grammar and not a shell emulator.
//
// The first version of this code tried to work out what bash would execute: it tracked quotes, resolved escapes,
// held quoted whitespace as placeholders, reasoned about globs and split words itself. Three review rounds found
// ten separate escapes in it, and every one had the same shape — the analysis and the shell disagreed about one of
// bash's expansion stages, and the disagreement always favoured whoever wrote the command:
//
//   cat lin*/o.txt   pathname expansion chose a symlinked directory the check never saw
//   cat "p q"        quote removal turned one filename into two harmless-looking names
//   cat ''2>&1       an empty pair of quotes started a word, so the `2` was read as a file descriptor
//   cat p\ q         the backslash branch did neither of the things the quote branch had just been fixed to do
//   cat a<TAB>b      all quoted whitespace collapsed to one placeholder, so a different file was checked
//   cat a<CR>b       word splitting used JavaScript's \s where bash uses IFS
//   cat z<CR>        the trailing trim used JavaScript's whitespace, one line below the split that was just fixed
//   cat f<SOH>ile    a raw control character forged a whitespace placeholder
//   cat \'q          a quote that was part of the filename was stripped from it
//   cat cls/[]a]     bash bracket classes are not JavaScript character classes
//
// Bash performs brace, tilde, parameter, command-substitution, arithmetic, word-splitting and pathname expansion,
// then quote removal, with IFS and locale-dependent collation in the middle. Re-implementing that correctly is not
// a realistic goal for a permission gate, and each fix only moved the divergence one stage along.
//
// So this gate no longer asks what bash would do. It accepts ONLY commands where the answer is trivial: one simple
// command, plain words separated by spaces, built from characters that cannot trigger any expansion or quote
// removal at all. For such a command the words below ARE the argv the program receives, by construction — there is
// no stage left to disagree about. Everything else is refused without analysis, which is also why this file no
// longer needs to know what `2>&1`, `~`, `{a,b}` or `[[:alpha:]]` mean.
//
// The agent loses quoted patterns and globs from Bash. It has the Grep and Glob tools for both — structured input,
// through this same gate — and BASH_RULES tells it so.
// ---------------------------------------------------------------------------------------------------------------

// Printable ASCII only: a control character, a tab or a non-ASCII byte is refused rather than reasoned about.
const PRINTABLE_ASCII = /^[\x20-\x7e]*$/;

// One word: no quote, backslash, glob metacharacter, `$`, backtick, brace, operator, `#`, `!` or space. `~` is
// legal only after the first character, because bash expands a word-initial `~` and leaves `HEAD~2` alone.
const SAFE_WORD = /^[A-Za-z0-9._/@=+:,%^-][A-Za-z0-9._/@=+:,%^~-]*$/;

// ...and not in the one mid-word position bash still expands: inside an ASSIGNMENT-SHAPED word, immediately
// after the `=`, or after any later `:`. So `a=~/x` and `a=b:~/x` become `a=/home/runner/x`, while `a:~x`,
// `9=~/x`, `a-b=~/x` and `HEAD~2:file` are all literal — measured against bash, not assumed. A fuzz of 3,475
// accepted commands against real argv found exactly this stage and nothing else. FORBIDDEN_PATH already denied
// these, but the rewrite rests on "the words here ARE the argv", and that invariant should hold on its own rather
// than depend on a rule in a different concern two functions away.
const ASSIGNMENT_TILDE = /^[A-Za-z_][A-Za-z0-9_]*\+?=(?:[^:]*:)*~/;

// The argv bash would build, or unsafe. `segments` is kept for callers that match a whole command line; there is
// at most one, because every operator is refused.
export function analyzeShell(command) {
  // Surrounding whitespace is trimmed before the ASCII test: a model routinely ends a command with a newline, and
  // the old walk trimmed it, so refusing `git status\n` outright is a lost turn for nothing. Trimming can only
  // shrink the string — an all-whitespace command still lands on `!words.length`, and an INTERIOR newline or tab
  // still fails the test, which is what matters (it could otherwise separate two commands).
  const cmd = String(command ?? '').replace(/^[ \t\n]+|[ \t\n]+$/g, '');
  if (!PRINTABLE_ASCII.test(cmd)) return { words: [], segments: [], unsafe: true };
  const words = cmd.split(' ').filter(Boolean);
  if (!words.length || !words.every((w) => SAFE_WORD.test(w) && !ASSIGNMENT_TILDE.test(w))) return { words: [], segments: [], unsafe: true };
  return { words, segments: [words.join(' ')], unsafe: false };
}

// getopt_long accepts any unambiguous PREFIX of a long option, so denying `--files-from` never denied
// `--files`, `--file` or `--f` — and `file --f=list.txt` performed the exact indirection escape the deny list was
// written to stop, verified against the real binary. Enumerating forbidden spellings loses to a parser that
// expands abbreviations, the same way emulating bash lost to bash. So this enumerates the flags a review actually
// needs, matched exactly, and refuses every other one. The deny-flag regexes stay as a second layer for the
// spellings they do catch.
const ALLOWED_LONG_FLAGS = new Set([
  '--', '--oneline', '--format', '--stat', '--numstat', '--name-only', '--name-status', '--no-color', '--color',
  '--include', '--exclude', '--porcelain', '--no-index', '--summarize', '--human-readable', '--count',
  '--line-number', '--recursive', '--files-with-matches', '--fixed-strings', '--extended-regexp',
  '--ignore-case', '--word-regexp', '--max-count', '--after-context', '--before-context', '--context',
]);

// The commands that WAIT ON STDIN when given nothing to read, and how many non-flag operands each needs before
// it is reading a file instead. That is the whole rule — a command waiting on stdin blocks until the tool's own
// timeout and spends the review's budget on nothing — so only the commands that actually wait belong here.
//
// `du`, `file` and `stat` were in this list and are not any more: `du` with no operand summarises the working
// directory (like `ls` and `find`), and `file`/`stat` print a usage error and exit. None of them blocks, so
// refusing them cost a denied turn and told the agent about the grammar rather than about a missing operand.
const STDIN_WITHOUT_OPERANDS = { cat: 1, head: 1, tail: 1, wc: 1, grep: 2 };

// Short letters, per command, and the block has to sit against the table it describes — inserting the constant
// above between the two left this reading as documentation for the wrong one.
//
// Notice what is absent: `f`/`F` for tail (never returns), `f` for file (indirection), and `d` for grep
// (`-d recurse`). On symlinks the rule is narrower than "no `L`/`H` anywhere", which is what this said while the
// table said otherwise: `L` is allowed for `git` deliberately — a `blame`/`log` LINE RANGE, not a dereference —
// and `H` is in grep's list (`--with-filename`, which opens nothing).
//
// And for the commands that WALK A TREE the refusal does not come from this table alone. `ls`, `du` and `find`
// have explicit entries in `DENY_FLAGS_BY_COMMAND`, so a dereference flag is refused there whatever is written
// here — but `file` has no such entry for `L`, and its absence from this line is the only thing stopping it.
// Adding a letter to `file` is therefore unguarded by anything else. This table is what a maintainer consults
// before adding a command, so it has to be true about itself.
const ALLOWED_SHORT_FLAGS = {
  git: 'pnLC',
  cat: 'nbs',
  ls: 'lahtr1dSR',
  head: 'ncq',
  tail: 'ncq',
  wc: 'lwcmL',
  // `f` is grep's pattern FILE, which holds patterns rather than filenames, so it is not the indirection the
  // `file`/`wc`/`du` variants are. Its long spelling stays out of ALLOWED_LONG_FLAGS on purpose: `--file` is an
  // unambiguous prefix of wc's `--files0-from`, so allowing it there would reopen exactly that hole.
  grep: 'rnicleEFfwovABChHqsam',
  find: '',
  stat: 'c',
  file: 'bih',
  du: 'shac',
  pwd: '',
  echo: 'n',
};

// find does not use getopt_long: its predicates are exact words, so they are listed as words.
const FIND_PREDICATES = new Set([
  '-name', '-iname', '-type', '-maxdepth', '-mindepth', '-path', '-ipath', '-not', '-o', '-a', '-and', '-or',
  '-print', '-newer', '-size', '-empty', '-regex', '-prune', '-quit',
  // `-follow` is deliberately NOT here: it makes the walk follow symlinks, which is the whole point of denying
  // `-L`. (An earlier edit left the two glued together as `-follow-never`, a word find has never had.)
]);

// Every flag in the command must be one this review needs. Values attached to a flag are not flags.
export function flagsAllowed(words) {
  const command = words[0];
  const shorts = ALLOWED_SHORT_FLAGS[command];
  if (shorts === undefined) return false;
  return words.slice(1).every((word) => {
    if (!word.startsWith('-')) return true;
    if (word.startsWith('--')) return ALLOWED_LONG_FLAGS.has(word.split('=')[0]);
    if (/^-\d+$/.test(word)) return true; // `-5`, `-20`: a count, not a flag cluster
    if (command === 'find') return FIND_PREDICATES.has(word);
    // A short cluster, up to its attached value: `-n40` is `n`, `-L10,20` is `L`, `-f/etc/passwd` is `f`.
    const cluster = word.slice(1).replace(/[0-9,.:=/-].*$/, '');
    return cluster.length > 0 && [...cluster].every((ch) => shorts.includes(ch));
  });
}

// The program allowlist and the flag denials, as one predicate. `isAllowedBash` calls it rather than repeating
// the two checks: they were briefly inlined there, which left this function reachable only from the tests — so the
// ALLOWED/DENIED corpora were asserting against a copy production did not run.
export function isReadOnlyShell(command) {
  const { words, segments, unsafe } = analyzeShell(command);
  if (unsafe || segments.length === 0) return false;
  return segments.every((s) => BASH_ALLOW.some((re) => re.test(s)) && !hasDeniedFlag(s)) && flagsAllowed(words);
}

// Locations that expose credentials even to a read-only agent: process environments, the git credential
// helper config actions/checkout may leave behind, and home-directory tool configs.
// `.example`/`.template`/`.sample` are committed templates, and reading one tells the agent what a config holds
// without holding it. Spelled out as an exception rather than "the name may not continue", which would also have
// stopped denying `.env.local` — a real secrets file.
const TEMPLATE_SUFFIX = '(?!\\.(example|template|sample))';

export const FORBIDDEN_PATH = new RegExp(
  `(^|[\\s"'=:])~|\\/proc\\/|\\/dev\\/(fd|stdin)|\\.git\\/config|(^|[\\s/"'=:])\\.(git-credentials|config|claude|npmrc|netrc|ssh|env|aws|gnupg|docker|kube|gradle|m2)${TEMPLATE_SUFFIX}(\\b|$)`,
);

// The repository's own secret files, by name, from the one per-repository file (repo.mjs). Defence in depth: the
// path rules refuse them wherever they appear in a path or a command, and `redact` cannot know their contents.
const escapeRegex = (name) => name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
export const REPO_SECRET_PATH = new RegExp(
  `(^|[\\s"'=:\\/])(${REPO_SECRET_FILES.map(escapeRegex).join('|')})${TEMPLATE_SUFFIX}(\\b|$)`,
);

// Where the agent may read: the checkout and the runner temp dir (which holds the diff). Anything absolute
// outside these, any `..`, or any existing path whose *real* location (symlinks resolved) is outside them is
// refused — so neither an absolute root nor a symlink committed by the PR can lead a recursive read to a
// credential directory.
export const safeRealpath = (p) => {
  try {
    return realpathSync(p);
  } catch {
    return p;
  }
};

// The diff file is the only thing outside the checkout the agent needs; the root is that file, not the temp dir.
// The directory is realpath'd (it exists; the file does not yet), so the root and the later resolution of the
// written file agree even where the temp path has a symlinked component, e.g. macOS /var -> /private/var.
export const diffPath = () => join(safeRealpath(process.env.RUNNER_TEMP || tmpdir()), `pr-${PR_NUMBER()}.diff`);

// The pull request's checkout: what the agent reads and what the path rules confine it to. Named by the workflow
// (`REVIEW_CHECKOUT`), because the job's workspace also holds the harness the job executes — checked out from the
// base branch beside it — and that tree is not the agent's business. The fallbacks are for a local run and the
// tests, which check out one tree.
export const checkoutRoot = () => process.env.REVIEW_CHECKOUT || process.env.GITHUB_WORKSPACE || process.cwd();
export const readRoots = () => [checkoutRoot(), diffPath()].map(safeRealpath);

// No quote handling here: the grammar refuses quote characters outright, so a path reaching this function is
// already the literal name the program will open.
// The base a relative token is resolved against. It is the checkout, stated explicitly rather than inherited from
// wherever the harness happens to run, and the agent's shell cannot drift away from it: `cd` (and `pushd`) are not
// on BASH_ALLOW, so every `cd …` segment is refused, and `git -C <path>` still has that path confined below.
export const agentCwd = () => checkoutRoot();

export function isPathAllowed(rawPath, roots = readRoots(), cwd = agentCwd()) {
  const p = String(rawPath || '');
  if (p.split('/').includes('..')) return false;
  const within = (abs) => roots.some((root) => abs === root || abs.startsWith(root.endsWith('/') ? root : `${root}/`));
  if (p.startsWith('/') && !within(p)) return false;
  // Globs and not-yet-existing paths stop here; anything that exists must also resolve inside the roots.
  const abs = resolve(cwd, p);
  return !existsSync(abs) || within(safeRealpath(abs));
}

// A value attached to a flag is still a path: `--file=/p` and `-f/p` both name one.
const pathish = (tok) => {
  if (!tok.startsWith('-')) return tok;
  const eq = tok.indexOf('=');
  if (eq !== -1) return tok.slice(eq + 1);
  const slash = tok.indexOf('/');
  return slash !== -1 ? tok.slice(slash) : tok;
};

// The single predicate canUseTool applies to a Bash command — tested as a unit, not as its parts.
export function isAllowedBash(command, roots = readRoots(), cwd = agentCwd()) {
  const { words, unsafe } = analyzeShell(command);
  if (unsafe) return false;
  if (!isReadOnlyShell(command)) return false;
  const line = words.join(' ');
  if (FORBIDDEN_PATH.test(line) || REPO_SECRET_PATH.test(line)) return false;
  // grep's first positional is the PATTERN, not a path: a route literal like `/v1/library` must not be refused as
  // an absolute path outside the roots. Exempt only when nothing exists at that path, which is what makes the
  // exemption safe — an existing file is always checked, and a path that does not exist can leak nothing.
  const skip = new Set();
  if (words[0] === 'grep') {
    const first = words.findIndex((w, i) => i > 0 && !w.startsWith('-'));
    if (first !== -1 && !existsSync(resolve(cwd, words[first]))) skip.add(first);
  }
  // A command that would read STDIN because it was given nothing to read. The `-` and `-f=` rules below cover the
  // explicit spellings, and `tail -f` is refused by the flag allowlist, all for the same reason — a command
  // waiting on stdin blocks until the tool's own timeout and spends the review's budget on nothing. `cat` on its
  // own passed every one of those rules, because they only inspect words that exist. `grep` needs two operands
  // (a pattern AND a path); the rest need one.
  // A number is a flag's VALUE, not something to read: `tail -n 5` is a stdin read whose "operand" is the 5.
  // Deliberately a heuristic and not a table of which flags take values — that table is the emulator this gate
  // refuses to be, and getting it wrong fails open. Residual: a file actually named `5` is refused, and a
  // non-numeric separated value (`grep -m x`) is miscounted as an operand, which fails closed either way.
  const operands = words.slice(1).filter((w) => !w.startsWith('-') && !/^\d+$/.test(w));
  // `grep` normally needs two (a pattern and a path), but a RECURSIVE grep needs only the pattern: GNU grep
  // searches the working directory when given no path, so `grep -rn TODO` reads no stdin and is the spelling the
  // agent reaches for most. Refusing it would cost a denied call and teach nothing.
  const recursive = words.some((w) => /^-[A-Za-z]*[rR]/.test(w) || w === '--recursive' || w === '--dereference-recursive');
  const needed = words[0] === 'grep' && recursive ? 1 : STDIN_WITHOUT_OPERANDS[words[0]];
  if (needed > operands.length) return false;
  // Every word that could name a path. The program name is not one, and a bare flag is not either.
  return words.every((word, i) => {
    if (i === 0 || skip.has(i)) return true;
    // `-` means stdin, and a flag whose value is empty (`-f=`) hides the path the program will actually open from
    // `pathish`. Neither is legitimate in a review, and a command reading stdin can block until the deadline.
    if (word === '-' || /=$/.test(word)) return false;
    const tok = pathish(word);
    if (tok === '-') return false;
    if (!tok || tok.startsWith('-')) return true;
    return isPathAllowed(tok, roots, cwd);
  });
}

export const canUseToolForTest = (toolName, input) => canUseTool(toolName, input); // the permission gate is the boundary; it is unit-tested

export async function canUseTool(toolName, input) {
  if (READ_ONLY_TOOLS.has(toolName)) {
    // Every path-like field, not just the first present one. Grep's `pattern` is a regex searched *within*
    // `path`, so it is not a path and is not checked; Glob's `pattern` is a path glob and is.
    const pathFields = toolName === 'Grep' ? ['file_path', 'path', 'glob'] : ['file_path', 'path', 'pattern', 'glob'];
    const targets = pathFields.map((k) => input[k]).filter(Boolean).map(String);
    if (targets.some((t) => FORBIDDEN_PATH.test(t) || REPO_SECRET_PATH.test(t) || !isPathAllowed(t))) {
      console.log(`  [denied] ${toolName}: forbidden path`);
      return { behavior: 'deny', message: 'That location is off-limits in this review (process/credential data).' };
    }
    return { behavior: 'allow', updatedInput: input };
  }
  if (toolName === 'Bash') {
    // Only the command is inspected below, so nothing that changes how or where it runs may travel with it. The
    // SDK's BashInput is {command, timeout?, description?, run_in_background?}: the first three are inert, and the
    // last two are neutralised rather than refused — a backgrounded command would outlive the deadline and its
    // output would never be seen. An unknown field (a future `cwd`, say) is refused by name, because it could
    // relocate execution and make the relative paths in that command resolve somewhere this never checked.
    const INERT_BASH_FIELDS = ['command', 'timeout', 'description'];
    const NEUTRALISED_BASH_FIELDS = ['run_in_background', 'dangerouslyDisableSandbox'];
    const extra = Object.keys(input).filter((k) => ![...INERT_BASH_FIELDS, ...NEUTRALISED_BASH_FIELDS].includes(k));
    if (extra.length) {
      console.log(`  [denied] Bash: unexpected input fields: ${extra.join(', ')}`);
      return {
        behavior: 'deny',
        message: `Remove ${extra.map((k) => `\`${k}\``).join(', ')} and pass only \`command\` (plus \`timeout\`/\`description\`). Paths are relative to the checkout; the working directory cannot be changed.`,
      };
    }
    if (isAllowedBash(input.command)) {
      const updatedInput = { ...input };
      for (const k of NEUTRALISED_BASH_FIELDS) if (k in updatedInput) updatedInput[k] = false;
      return { behavior: 'allow', updatedInput };
    }
    console.log(`  [denied] Bash: ${redact(String(input.command || '')).slice(0, 200)}`);
    return { behavior: 'deny', message: BASH_DENY_MESSAGE };
  }
  console.log(`  [denied] ${toolName}`);
  return { behavior: 'deny', message: `${toolName} is not available in this read-only review. Use Read/Grep/Glob.` };
}

// Head + tail of the agent's answer for the run log, redacted, with every leading `::` (indented or not) broken by a
// zero-width space so no line can read as a workflow command even if the stop-commands bracket were missing.
export function boundedDump(text, max = maxDumpChars()) {
  const clean = redact(text); // redact the whole text first: a secret straddling the cut point must not survive as fragments
  const half = Math.floor(max / 2);
  const bounded = clean.length > max ? `${clean.slice(0, half)}\n…[${clean.length - max} chars omitted]…\n${clean.slice(-half)}` : clean;
  return bounded.replace(/^(\s*)::/gm, '$1\u200b::');
}

// Environment for the agent subprocess: the harness fetches the diff and posts the results, so the agent
// needs ANTHROPIC_API_KEY for its own calls and no GitHub credential at all.
// The agent inherits the job environment minus anything that looks like a credential. Naming the three tokens we
// know about would only ever be "we remembered to delete it"; the pattern makes adding a secret to this workflow
// unable to widen the agent's environment by accident. ANTHROPIC_API_KEY is kept: the SDK needs it.
const SECRET_ENV_RE = /(TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|PRIVATE_KEY|_KEY|KEYSTORE|API_KEY|WEBHOOK|DSN|SESSION)/i;

// An allowlist, because a denylist of name shapes is only as good as the names someone thought of: a secret called
// PLAY_SERVICE_ACCOUNT_JSON or FOO_PAT matches nothing in the pattern above and would have gone straight through.
// The agent needs its own API key, enough of a POSIX environment for the SDK's subprocess, and the runner's temp
// and workspace paths — nothing else. The pattern stays as a backstop for names a prefix admits (NODE_AUTH_TOKEN).
const AGENT_ENV_ALLOW = new Set([
  'ANTHROPIC_API_KEY', 'PATH', 'HOME', 'SHELL', 'USER', 'LOGNAME', 'PWD', 'TZ', 'TERM', 'LANG', 'CI',
  'TMPDIR', 'TEMP', 'TMP', 'RUNNER_TEMP', 'RUNNER_OS', 'RUNNER_ARCH', 'GITHUB_WORKSPACE',
]);

const AGENT_ENV_ALLOW_PREFIX = ['LC_', 'XDG_', 'NODE_', 'CLAUDE_CODE_'];

// Taken out of THIS process while the agent runs, then put back. `agentEnv` filters what is handed to the SDK;
// this is the half that does not depend on the SDK honouring it — a release that spawned with
// `{ ...process.env, ...options.env }` would make that filtering cosmetic, with every test here still green.
// `ANTHROPIC_API_KEY` is not withheld: the agent cannot authenticate without it, and it grants nothing on this
// pull request. What is withheld is exactly the two credentials that can write to it.
const WITHHOLD_WHILE_AGENT_RUNS = ['GITHUB_TOKEN', 'REVIEW_RESOLVE_TOKEN'];

// Wrapped around the agent SEAM rather than inside `runAgent`, for two reasons: every implementation of the seam
// passes through here (including the stubs the tests drive whole rounds with, so the guarantee is observable),
// and the isolation belongs to the act of calling an agent, not to one way of doing it. Safe because the harness
// is sequential — no GitHub call is in flight while the agent runs, and the client reads these at call time.
export async function withoutWriteTokens(fn) {
  const withheld = {};
  for (const name of WITHHOLD_WHILE_AGENT_RUNS) {
    if (process.env[name] !== undefined) {
      withheld[name] = process.env[name];
      delete process.env[name];
    }
  }
  try {
    return await fn();
  } finally {
    // Whatever happened — an answer, a deadline, a throw — the harness needs these back to post anything at all.
    for (const [name, value] of Object.entries(withheld)) process.env[name] = value;
  }
}

export function agentEnv(source = process.env) {
  const env = {};
  for (const [k, v] of Object.entries(source)) {
    if (!AGENT_ENV_ALLOW.has(k) && !AGENT_ENV_ALLOW_PREFIX.some((prefix) => k.startsWith(prefix))) continue;
    if (k !== 'ANTHROPIC_API_KEY' && SECRET_ENV_RE.test(k)) continue;
    env[k] = v;
  }
  return env;
}
