import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class MacroBaseTestCase: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      macros: [
        WithViewStoreMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }
}
