#!/bin/bash

    KEYCHAIN=IDZSwiftCommonCrypto.keychain
    SCRIPT_DIR=.

    # If this environment variable is missing, we must not be running on Travis.
    if [ -z "$KEY_PASSWORD" ]
    then
        return 0
    fi

    echo "*** Setting up code signing $KEYCHAIN ..."
    password=cibuild

    # Create a temporary keychain for code signing.
    security create-keychain -p "$password" "$KEYCHAIN"
    security default-keychain -s "$KEYCHAIN"
    security unlock-keychain -p "$password" "$KEYCHAIN"
    security set-keychain-settings -t 3600 -l "$KEYCHAIN"

    # Download the certificate for the Apple Worldwide Developer Relations
    # Certificate Authority.
    certpath="$SCRIPT_DIR/apple_wwdr.cer"
    curl 'https://developer.apple.com/certificationauthority/AppleWWDRCA.cer' > "$certpath"
    security import "$certpath" -k "$KEYCHAIN" -T /usr/bin/codesign

    # Import our development certificate.
    security import "./developer.p12" -k "$KEYCHAIN" -P "$KEY_PASSWORD" -T /usr/bin/codesign

