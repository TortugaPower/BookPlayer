#!/bin/bash
KEYCHAIN=IDZSwiftCommonCrypto.keychain

    # If this environment variable is missing, we must not be running on Travis.
    if [ -z "$KEY_PASSWORD" ]
    then
        return 0
    fi

    security delete-keychain "$KEYCHAIN"
    echo "Deleted keycain."
