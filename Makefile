PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max,OS=13.4
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p),OS=13.4
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 4 - 44mm,OS=6.2

default: test-all

test-all: test-swift test-workspace

test-swift:
	swift test \
		--enable-pubgrub-resolver \
		--enable-test-discovery \
		--parallel

test-workspace:
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_MACOS)"
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_TVOS)"
	xcodebuild test \
		-scheme "CaseStudies (SwiftUI)" \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme "CaseStudies (UIKit)" \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme MotionManager \
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
	swift format --in-place --recursive .

.PHONY: format
