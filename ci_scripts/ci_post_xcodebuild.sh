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
