#!/bin/sh

# Creates the archive's release in Sentry and attaches its commits: everything after the previous
# release's tag, up to the commit Xcode Cloud built. With them, Sentry's GitHub integration resolves
# an issue whose fix commit says `Fixes BOOKPLAYER-<id>` in the release that ships that commit.
#
# Xcode Cloud's clone has no tags (and maybe not the history), so the previous tag is read from
# GitHub: the repo is public, no credentials needed. Sentry reads the commits in between from GitHub
# as well. sentry-cli takes its token from SENTRY_AUTH_TOKEN.
#
# Run by ci_post_xcodebuild.sh for release archives. ARCHIVE_PATH and COMMIT default to Xcode Cloud's
# CI_ARCHIVE_PATH and CI_COMMIT; DRY_RUN=1 prints the sentry-cli commands instead of running them.

set -e

REPO="TortugaPower/BookPlayer"
ARCHIVE_PATH="${ARCHIVE_PATH:-$CI_ARCHIVE_PATH}"
COMMIT="${COMMIT:-$CI_COMMIT}"
export SENTRY_ORG="tortuga-power"
export SENTRY_PROJECT="bookplayer"

# The name the Sentry SDK reports: <bundle id>@<version>+<build>, read from the archived app itself.
PLIST=$(ls "$ARCHIVE_PATH"/Products/Applications/*.app/Info.plist | head -1)
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST"; }
VERSION=$(read_plist CFBundleShortVersionString)
RELEASE="$(read_plist CFBundleIdentifier)@$VERSION+$(read_plist CFBundleVersion)"

# The previous release is the highest version tag below this version (its own tag may exist already).
TAGS=$(git ls-remote --tags "https://github.com/$REPO.git")
PREVIOUS_TAG=$(echo "$TAGS" | sed -n 's#^[0-9a-f]*[[:space:]]*refs/tags/\([0-9][0-9.]*\)$#\1#p' | awk -v version="$VERSION" '
    function compare(a, b,    x, y, n, m, i) {
        n = split(a, x, "."); m = split(b, y, "."); if (m > n) n = m
        for (i = 1; i <= n; i++) if (x[i] + 0 != y[i] + 0) return x[i] + 0 < y[i] + 0 ? -1 : 1
        return 0
    }
    compare($0, version) < 0 && (best == "" || compare($0, best) > 0) { best = $0 }
    END { print best }')
# An annotated tag lists its commit on the `^{}` line; a lightweight one on its own line.
PREVIOUS_COMMIT=$(echo "$TAGS" | awk -v ref="refs/tags/$PREVIOUS_TAG" '
    $2 == ref "^{}" { peeled = $1 } $2 == ref { plain = $1 } END { print (peeled != "" ? peeled : plain) }')

if [ -n "$PREVIOUS_TAG" ] && [ -n "$PREVIOUS_COMMIT" ]; then
    COMMITS="$REPO@$PREVIOUS_COMMIT..$COMMIT"
else
    COMMITS="$REPO@$COMMIT"
fi
echo "Sentry release $RELEASE: commits after ${PREVIOUS_TAG:-no earlier tag} ($COMMITS)"

run() { if [ -n "$DRY_RUN" ]; then echo "+ $*"; else "$@"; fi; }
run sentry-cli releases new "$RELEASE"
run sentry-cli releases set-commits "$RELEASE" --commit "$COMMITS"
