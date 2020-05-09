PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max,OS=13.4.1
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV 4K (at 1080p),OS=13.4

default: test-all

test-all: test-swift test-workspace

test-swift:
	swift test \
		--enable-pubgrub-resolver \
		--enable-test-discovery \
		--parallel

test-workspace:
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_MACOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_TVOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme "CaseStudies (SwiftUI)" \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme "CaseStudies (UIKit)" \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme MotionManager \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme Search \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme SpeechRecognition \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme TicTacToe \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme Todos \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet
	xcodebuild test \
		-workspace ./Examples/ComposableArchitecture.xcworkspace \
		-scheme VoiceMemos \
		-destination platform="$(PLATFORM_IOS)" \
		-quiet

format:
	swift format --in-place --recursive .

.PHONY: format
