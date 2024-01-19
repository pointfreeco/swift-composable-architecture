CONFIG = debug
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iOS 17.2,iPhone \d\+ Pro [^M])
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,tvOS 17.2,TV)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,watchOS 10.2,Watch)

default: test-all

test-all: test-examples
	$(MAKE) CONFIG=debug test-library
	$(MAKE) CONFIG=release test-library

test-library:
	for platform in "$(PLATFORM_IOS)" "$(PLATFORM_MACOS)" "$(PLATFORM_MAC_CATALYST)" "$(PLATFORM_TVOS)" "$(PLATFORM_WATCHOS)"; do \
		xcodebuild test \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$$platform" || exit 1; \
	done;

build-for-library-evolution:
	swift build \
		-c release \
		--target ComposableArchitecture \
		-Xswiftc -emit-module-interface \
		-Xswiftc -enable-library-evolution

DOC_WARNINGS = $(shell xcodebuild clean docbuild \
	-scheme ComposableArchitecture \
	-destination platform="$(PLATFORM_MACOS)" \
	-quiet \
	2>&1 \
	| grep "couldn't be resolved to known documentation" \
	| sed 's|$(PWD)|.|g' \
	| tr '\n' '\1')
test-docs:
	@test "$(DOC_WARNINGS)" = "" \
		|| (echo "xcodebuild docbuild failed:\n\n$(DOC_WARNINGS)" | tr '\1' '\n' \
		&& exit 1)

test-examples:
	for scheme in "CaseStudies (SwiftUI)" "CaseStudies (UIKit)" Search SyncUps SpeechRecognition TicTacToe Todos VoiceMemos; do \
		xcodebuild test \
			-skipMacroValidation \
			-scheme "$$scheme" \
			-destination platform="$(PLATFORM_IOS)" || exit 1; \
	done

test-integration:
	xcodebuild test \
		-skipMacroValidation \
		-scheme "Integration" \
		-destination platform="$(PLATFORM_IOS)" || exit 1; 

benchmark:
	swift run --configuration release \
		swift-composable-architecture-benchmark

format:
	find . \
		-path '*/Documentation.docc' -prune -o \
		-name '*.swift' \
		-not -path '*/.*' -print0 \
		| xargs -0 swift format --ignore-unparsable-files --in-place

.PHONY: format test-all test-swift test-workspace

define udid_for
$(shell xcrun simctl list devices available '$(1)' | grep '$(2)' | sort -r | head -1 | awk -F '[()]' '{ print $$(NF-3) }')
endef
