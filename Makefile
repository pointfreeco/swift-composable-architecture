PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p)

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
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_MACOS)" \
		-quiet
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_TVOS)" \
		-quiet
	xcodebuild test \
		-scheme "CaseStudies (SwiftUI)" \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme "CaseStudies (UIKit)" \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme MotionManager \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme Search \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme SpeechRecognition \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme TicTacToe \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme Todos \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-scheme VoiceMemos \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet

format:
	swift format --in-place --recursive .

.PHONY: format
