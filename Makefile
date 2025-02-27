CONFIG = Debug

DERIVED_DATA_PATH = ~/.derivedData/$(CONFIG)

PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iPhone)
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,TV)
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for,Vision)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,Watch)

PLATFORM = IOS
DESTINATION = platform="$(PLATFORM_$(PLATFORM))"

PLATFORM_ID = $(shell echo "$(DESTINATION)" | sed -E "s/.+,id=(.+)/\1/")

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

warm-simulator:
	@test "$(PLATFORM_ID)" != "" \
		&& xcrun simctl boot $(PLATFORM_ID) \
		&& open -a Simulator --args -CurrentDeviceUDID $(PLATFORM_ID) \
		|| exit 0

xcodebuild: warm-simulator
	$(XCODEBUILD)

xcodebuild-raw: warm-simulator
	$(XCODEBUILD_COMMAND)

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
		| xargs -0 xcrun swift-format --ignore-unparsable-files --in-place

.PHONY: build-for-library-evolution format warm-simulator xcodebuild xcodebuild-raw

define udid_for
$(shell xcrun simctl list --json devices available '$(1)' | jq -r '[.devices|to_entries|sort_by(.key)|reverse|.[].value|select(length > 0)|.[0]][0].udid')
endef
