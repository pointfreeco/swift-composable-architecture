#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  class MacroBaseTestCase: XCTestCase {
    override func invokeTest() {
      MacroTesting.withMacroTesting(
        record: .failed,
        macros: [
          ObservableStateMacro.self,
          ObservationStateTrackedMacro.self,
          ObservationStateIgnoredMacro.self,
          PresentsMacro.self,
          ViewActionMacro.self,
        ]
      ) {
        super.invokeTest()
      }
    }
  }
#endif
