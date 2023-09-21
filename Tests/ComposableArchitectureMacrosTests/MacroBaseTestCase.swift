import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class MacroBaseTestCase: XCTestCase {
  override func invokeTest() {
    MacroTesting.withMacroTesting(
      //isRecording: true,
      macros: testMacros
    ) {
      super.invokeTest()
    }
  }
}

let testMacros: [Macro.Type] = [
  ObservableStateMacro.self,
  WithViewStoreMacro.self,
  ObservationStateTrackedMacro.self,
  ObservationStateIgnoredMacro.self,
]
