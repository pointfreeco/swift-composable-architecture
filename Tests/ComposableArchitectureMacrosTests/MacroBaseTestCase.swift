import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class MacroBaseTestCase: XCTestCase {
  override func invokeTest() {
    MacroTesting.withConfiguration(macros: testMacros) {
      super.invokeTest()
    }
  }
}

let testMacros: [String: Macro.Type] = [
  "ObservableState": ObservableStateMacro.self,
  "ObservationTrackedWhen": ObservationTrackedWhenMacro.self,
  "WithViewStore": WithViewStoreMacro.self,
]
