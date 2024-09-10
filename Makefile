CONFIG = debug
PLATFORM = iOS
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iOS 17.5,iPhone \d\+ Pro [^M])
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,tvOS 17.5,TV)
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for,visionOS 1.2,Vision)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,watchOS 10.5,Watch)

TEST_RUNNER_CI = $(CI)

default: test-all

test-all: test-examples
	$(MAKE) CONFIG=debug test-library
	$(MAKE) CONFIG=release test-library

xcodebuild:
	if test "$(PLATFORM)" = "iOS"; \
		then xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$(PLATFORM_IOS)" \
			-derivedDataPath ~/.derivedData/$(CONFIG); \
		elif test "$(PLATFORM)" = "macOS"; \
		then xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$(PLATFORM_MACOS)" \
			-derivedDataPath ~/.derivedData/$(CONFIG); \
		elif test "$(PLATFORM)" = "tvOS"; \
		then xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$(PLATFORM_TVOS)" \
			-derivedDataPath ~/.derivedData/$(CONFIG); \
		elif test "$(PLATFORM)" = "watchOS"; \
		then xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$(PLATFORM_WATCHOS)" \
			-derivedDataPath ~/.derivedData/$(CONFIG); \
		elif test "$(PLATFORM)" = "visionOS"; \
		then xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$(PLATFORM_VISIONOS)" \
			-derivedDataPath ~/.derivedData/$(CONFIG); \
		elif test "$(PLATFORM)" = "macCatalyst"; \
		then xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-configuration $(CONFIG) \
			-workspace .github/package.xcworkspace \
			-scheme ComposableArchitecture \
			-destination platform="$(PLATFORM_MAC_CATALYST)" \
			-derivedDataPath ~/.derivedData/$(CONFIG); \
		else exit 1; \
		fi;	

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

test-example:
	xcodebuild test \
		-skipMacroValidation \
		-scheme "$(SCHEME)" \
		-destination platform="$(PLATFORM_IOS)" \
		-derivedDataPath ~/.derivedData

test-integration:
	xcodebuild test \
		-skipMacroValidation \
		-scheme "Integration" \
		-destination platform="$(PLATFORM_IOS)"

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
