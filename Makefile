CONFIG = Debug

DERIVED_DATA_PATH = ~/.derivedData/$(CONFIG)

PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iOS,iPhone \d\+ Pro [^M])
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,tvOS,TV)
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for,visionOS,Vision)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,watchOS,Watch)

PLATFORM = IOS
DESTINATION = platform="$(PLATFORM_$(PLATFORM))"

SCHEME = ComposableArchitecture

WORKSPACE = ComposableArchitecture.xcworkspace

XCODEBUILD_ARGUMENT = test

XCODEBUILD_FLAGS = \
	-configuration $(CONFIG) \
	-derivedDataPath $(DERIVED_DATA_PATH) \
	-destination $(DESTINATION) \
	-scheme "$(SCHEME)" \
	-skipMacroValidation \
	-workspace $(WORKSPACE)

XCODEBUILD_COMMAND = xcodebuild $(XCODEBUILD_ARGUMENT) $(XCODEBUILD_FLAGS)

ifneq ($(strip $(shell which xcbeautify)),)
	XCODEBUILD = set -o pipefail && $(XCODEBUILD_COMMAND) | xcbeautify --quiet
else
	XCODEBUILD = $(XCODEBUILD_COMMAND)
endif

TEST_RUNNER_CI = $(CI)

xcodebuild:
	$(XCODEBUILD)

build-for-library-evolution:
	swift build \
		-q \
		-c release \
		--target ComposableArchitecture \
		-Xswiftc -emit-module-interface \
		-Xswiftc -enable-library-evolution

format:
	find . \
		-path '*/Documentation.docc' -prune -o \
		-name '*.swift' \
		-not -path '*/.*' -print0 \
		| xargs -0 swift format --ignore-unparsable-files --in-place

.PHONY: build-for-library-evolution format xcodebuild

define udid_for
$(shell xcrun simctl list devices available '$(1)' | grep '$(2)' | sort -r | head -1 | awk -F '[()]' '{ print $$(NF-3) }')
endef
