// The per-repository half of the sandbox. Everything else in this directory is portable; this file and
// `../review-guide.md` are the two that change when the harness is copied to another repository. A copy that
// keeps these lists gets rules that match nothing of its own and no rule naming its secret files — so review
// both when you port.

// Files in the checkout that hold credentials even though they are gitignored. `BuildConfiguration/Debug.xcconfig`
// carries a developer's real Sentry DSN, RevenueCat key, team id and mocked bearer token; CI materialises it from
// `Debug.template.xcconfig`, and nothing stops a later step from writing real values into it. The template is a
// different name and stays readable. `Release.xcconfig` is deliberately NOT listed: despite its `.gitignore` entry
// it is tracked, holds placeholders, and is rewritten with real values only on Xcode Cloud — a change to it is
// something to review, and the shapes below are the backstop if a real value ever lands in it.
export const REPO_SECRET_FILES = ['Debug.xcconfig'];

// Secret SHAPES this repository's code and configuration can contain, applied by `redact` after the generic ones
// (Anthropic keys, GitHub tokens, PEM private keys). Each entry carries the example(s) that prove it and a
// look-alike that must pass untouched: the harness's own test runs both, so a shape cannot be listed without
// working and cannot eat prose. (The mocked bearer token is deliberately not pattern-matched: it has no shape
// that would not mangle prose, and it lives only in the gitignored Debug.xcconfig the path rule already refuses.)
export const REPO_SECRET_SHAPES = [
  {
    // A Sentry DSN, with OR without its scheme: an xcconfig treats `//` as a comment, so `BP_SENTRY_DSN` holds
    // `<key>@o<org>.ingest.<region>.sentry.io/<id>` and AppDelegate prepends `https://` at startup. A pattern that
    // required the scheme (as a URL-shaped DSN elsewhere would) misses the one form this repository stores. Any
    // sentry.io host, and the legacy `key:secret@` form too.
    pattern: /(?:https:\/\/)?\b[0-9a-f]{16,}(?::[0-9a-f]+)?@[\w.-]*sentry\.io\/\d+/gi,
    replacement: '[redacted sentry dsn]',
    example: [
      'BP_SENTRY_DSN = 0123456789abcdef0123456789abcdef@o12345.ingest.us.sentry.io/6789', // the xcconfig form
      'dsn https://0123456789abcdef0123456789abcdef@o12345.ingest.sentry.io/6789 set', // the URL form
      'https://0123456789abcdef0123456789abcdef:fedcba9876543210@sentry.io/1234', // legacy key:secret@
    ],
    keeps: [
      'see sentry.io/docs and o1.ingest.sentry.io for setup',
      'BP_SENTRY_DSN = replace.me', // the tracked Release.xcconfig placeholder
      'options.dsn = "https://\\(sentryDSN)"',
    ],
  },
  {
    // RevenueCat and store keys: `BP_REVENUECAT_KEY` is an `appl_` key.
    pattern: /\b(goog|appl|amzn|strp|rcb)_[A-Za-z0-9]{20,}\b/g,
    replacement: '[redacted]',
    example: 'BP_REVENUECAT_KEY = appl_' + 'A'.repeat(27),
    keeps: ['BP_REVENUECAT_KEY = replace.me', 'the appl_ prefix marks the App Store key'],
  },
];
