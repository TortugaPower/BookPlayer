#!/bin/bash
pushd /Users/idz/Documents/src/IDZSwiftCommonCrypto/IDZSwiftCommonCrypto
xcodebuild test -scheme IDZSwiftCommonCrypto -destination 'platform=iOS Simulator,name=iPhone 6,OS=9.0' > log.out 2>&1
popd
