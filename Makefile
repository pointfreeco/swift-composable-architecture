PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 7 (45mm)

default: test-all

test-all: test-examples
	CONFIG=debug test-library 
	CONFIG=release test-library 
	CONFIG=debug test-library 
	CONFIG=release test-library 

test-library:
	for platform in "$(PLATFORM_IOS)" "$(PLATFORM_MACOS)" "$(PLATFORM_MAC_CATALYST)" "$(PLATFORM_TVOS)" "$(PLATFORM_WATCHOS)"; do \
		xcodebuild test \
			-configuration $(CONFIG) \
			-workspace ComposableArchitecture.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$$platform" || exit 1; \
	done;

build-for-library-evolution:
	swift build \
		-c release \
		--target ComposableArchitecture \
		-Xswiftc -emit-module-interface \
		-Xswiftc -enable-library-evolution

DOC_WARNINGS := $(shell xcodebuild clean docbuild \
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
	for scheme in "CaseStudies (SwiftUI)" "CaseStudies (UIKit)" Search SpeechRecognition TicTacToe Todos VoiceMemos; do \
		xcodebuild test \
			-scheme $$scheme \
			-destination platform="$(PLATFORM_IOS)"; \
	done

benchmark:
	swift run --configuration release \
		swift-composable-architecture-benchmark

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Examples ./Package.swift ./Sources ./Tests

.PHONY: format test-all test-swift test-workspace
