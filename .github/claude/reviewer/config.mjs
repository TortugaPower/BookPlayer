// Environment access for the harness: the PR coordinates the workflow passes in, the run's flags, and the
// `num` knob reader. Read when ASKED, never at import — the tests load the harness once per scenario with a
// different environment each time, and a value frozen at import would be the first scenario's for all of them.

// A non-numeric override must fall back to the default rather than become NaN: setTimeout(fn, NaN) fires
// immediately, which would degrade every run to the "incomplete" note with no hint why.
export const num = (v, fallback) => (Number.isFinite(Number(v)) && Number(v) > 0 ? Number(v) : fallback);

export const DRY_RUN = () => process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';

export const RUN_URL = () => process.env.RUN_URL || '';

export function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

// Validated in runReview(), not here: importing this module (e.g. from a test) must not throw, and a value read at
// call time is the current scenario's.
export const PR_NUMBER = () => Number(process.env.PR_NUMBER || 0);

export const COMMIT = () => process.env.COMMIT || ''; // PR head SHA — anchors inline comments

export const BASE = () => process.env.BASE_REF || 'main';
