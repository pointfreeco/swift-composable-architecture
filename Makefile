COMMAND = 
CONFIG = debug
PLATFORM = iOS
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iOS,iPhone \d\+ Pro [^M])
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,tvOS,TV)
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for,visionOS,Vision)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,watchOS,Watch)
SCHEME = ComposableArchitecture
TEST_RUNNER_CI = $(CI)

XCODEBUILD = xcodebuild $(COMMAND) \
			-skipMacroValidation \
			-quiet \
			-configuration $(CONFIG) \
			-scheme $(SCHEME) \
			-derivedDataPath ~/.derivedData/$(CONFIG) \
			-testPlan $(TEST_PLAN)

default: test-all

test-all: test-examples
	$(MAKE) CONFIG=debug test-library
	$(MAKE) CONFIG=release test-library

xcodebuild:
	if test "$(PLATFORM)" = "iOS"; \
		then $(XCODEBUILD) \
			-destination platform="$(PLATFORM_IOS)"; \
		elif test "$(PLATFORM)" = "macOS"; \
		then $(XCODEBUILD) \
			-destination platform="$(PLATFORM_MACOS)"; \
		elif test "$(PLATFORM)" = "tvOS"; \
		then $(XCODEBUILD) \
			-destination platform="$(PLATFORM_TVOS)"; \
		elif test "$(PLATFORM)" = "watchOS"; \
		then $(XCODEBUILD) \
			-destination platform="$(PLATFORM_WATCHOS)"; \
		elif test "$(PLATFORM)" = "visionOS"; \
		then $(XCODEBUILD) \
			-destination platform="$(PLATFORM_VISIONOS)"; \
		elif test "$(PLATFORM)" = "macCatalyst"; \
		then $(XCODEBUILD) \
			-destination platform="$(PLATFORM_MAC_CATALYST)"; \
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

test-integration:
	xcodebuild test \
		-skipMacroValidation \
		-quiet \
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
