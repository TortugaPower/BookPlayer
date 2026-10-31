#!/bin/sh

set -e

# This is necessary in order to have sentry-cli
# install locally into the current directory
export INSTALL_DIR=$PWD

if [[ $(command -v sentry-cli) == "" ]]; then
    echo "Installing Sentry CLI"
    curl -sL https://sentry.io/get-cli/ | bash
fi

echo "Uploading dSYM to Sentry"

sentry-cli --auth-token $SENTRY_AUTH_TOKEN \
    upload-dif --org 'tortuga-power' \
    --project 'bookplayer' \
    $CI_ARCHIVE_PATH

# Release archives only: a build of another branch would claim commits that aren't its own. It's
# metadata, so a failure here warns instead of failing the build (and with it the upload).
if [ "$CI_XCODEBUILD_ACTION" = "archive" ] && [[ "$CI_BRANCH" == release-* ]]; then
    echo "Attaching commits to the Sentry release"
    python3 -I "$(dirname "$0")/sentry_release_commits.py" --archive "$CI_ARCHIVE_PATH" --head "$CI_COMMIT" \
        --repo TortugaPower/BookPlayer --project bookplayer \
        || echo "warning: couldn't attach the commits to the Sentry release"
fi
