REPO=IDZPodspecs
NAME=IDZSwiftCommonCrypto

IOS_VERSION=9.2

PG=README.playground
RSRC_DIR=$(PG)/Resources

XC=xcodebuild 
XCPP=xcpretty
CS_FLAGS=CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

$(PG): README.md
	playground README.md -p ios 
	mkdir -p  ${RSRC_DIR}
	cp Riscal.jpg ${RSRC_DIR}
	git config --global push.default simple
	git diff-files --exit-code; if [[ "$?" == "1" ]]; then git commit -a -m "Playground update from Travis [ci skip]"; git push; fi
all: 
	$(XC) build -target "IDZSwiftCommonCrypto (iOS)" $(CS_FLAGS) | xcpretty
	$(XC) build -target "IDZSwiftCommonCrypto (OSX)" $(CS_FLAGS) | xcpretty
	$(XC) build -target "IDZSwiftCommonCrypto (tvOS)" $(CS_FLAGS) | xcpretty
	$(XC) build -target "IDZSwiftCommonCrypto (watchOS)" $(CS_FLAGS) | xcpretty
	$(XC) test -scheme "IDZSwiftCommonCrypto (iOS)" -destination 'platform=iOS Simulator,name=iPhone 6' | xcpretty
	$(XC) test -scheme "IDZSwiftCommonCrypto (OSX)" | xcpretty
	$(XC) test -scheme "IDZSwiftCommonCrypto (tvOS)" -destination 'platform=tvOS Simulator,name=Apple TV 1080p'| xcpretty

#
# Build
#
build:
	$(XC) build -scheme IDZSwiftCommonCrypto -destination 'platform=iOS Simulator,name=iPhone 6,OS=${OS}' | $(XCPP)
test:
	$(XC) test -scheme IDZSwiftCommonCrypto -destination 'platform=iOS Simulator,name=iPhone 6,OS=${OS}' | $(XCPP)
clean:
	rm -rf $(PG)

# push tags to GitHub
push_tags:
	git push origin --tags

# Lint the podspec
lint_pod:
	pod spec lint --verbose ${NAME}.podspec --sources=https://github.com/iosdevzone/IDZPodspecs.git

# Push pod to private spec repository
push_pod:
	pod trunk push ${NAME}.podspec
