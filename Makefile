PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p)
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 4 - 44mm

default: test

test-all: test-library test-examples

test-library:
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_MACOS)"
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_TVOS)"
	xcodebuild \
		-scheme ComposableArchitecture_watchOS \
		-destination platform="$(PLATFORM_WATCHOS)"

test-examples:
	xcodebuild test \
		-scheme "CaseStudies (SwiftUI)" \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme "CaseStudies (UIKit)" \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme Search \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme SpeechRecognition \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme TicTacToe \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme Todos \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme VoiceMemos \
		-destination platform="$(PLATFORM_IOS)"

format:
	swift format --in-place --recursive \
		./Examples ./Package.swift ./Sources ./Tests

.PHONY: format test-all test-swift test-workspace
