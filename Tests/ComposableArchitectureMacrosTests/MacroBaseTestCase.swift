#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  class MacroBaseTestCase: XCTestCase {
    override func invokeTest() {
      MacroTesting.withMacroTesting(
        // isRecording: true,
        macros: [
          ObservableStateMacro.self,
          ObservationStateTrackedMacro.self,
          ObservationStateIgnoredMacro.self,
          // WithViewStoreMacro.self,
        ]
      ) {
        super.invokeTest()
      }
    }
  }
#endif
