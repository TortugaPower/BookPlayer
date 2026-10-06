// The install smoke check the workflow runs after `npm ci --ignore-scripts`. Loading the SDK's entry point proves
// only that JavaScript installed; what the review step needs minutes later is the native CLI binary the SDK
// spawns, from the platform package npm resolved for this runner — and that is what a lockfile written on another
// OS, or an extraction that lost a file mode, leaves out. So the binary is located the way the SDK locates it,
// checked for the execute bit, and RUN.
import { spawnSync } from 'node:child_process';
import { accessSync, constants } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { redact } from './sandbox.mjs';

const fail = (msg) => {
  console.error(`smoke check failed: ${redact(msg)}`);
  process.exit(1);
};

const sdk = await import('@anthropic-ai/claude-agent-sdk').catch((e) => fail(`the agent SDK does not load: ${redact(e.message)}`));
if (typeof sdk.query !== 'function') fail('the agent SDK installed but exports no query()');

const require = createRequire(import.meta.url);
const base = `@anthropic-ai/claude-agent-sdk-${process.platform}-${process.arch}`;
const candidates = process.platform === 'linux' ? [base, `${base}-musl`] : [base];
let bin = null;
for (const pkg of candidates) {
  try {
    bin = join(dirname(require.resolve(`${pkg}/package.json`)), process.platform === 'win32' ? 'claude.exe' : 'claude');
    break;
  } catch {
    // not this one
  }
}
if (!bin) fail(`no CLI package installed for ${process.platform}-${process.arch} (tried ${candidates.join(', ')})`);
try {
  accessSync(bin, constants.X_OK);
} catch {
  fail(`${bin} is present but not executable`);
}
const run = spawnSync(bin, ['--version'], { encoding: 'utf8', timeout: 30_000 });
// `error` is set when the binary could not be run at all (ENOEXEC from the wrong architecture, the timeout): status
// and signal are both null then, and the output is empty, so it is the only object carrying the cause.
if (run.error || run.status !== 0) {
  const cause = run.error ? `could not run: ${redact(run.error.message)}` : `exited ${run.status ?? run.signal}`;
  fail(`${bin} --version ${cause}: ${redact(String(run.stderr || run.stdout || '')).slice(0, 200)}`);
}
console.log(`agent SDK loads; CLI ${run.stdout.trim()} at ${bin}`);
