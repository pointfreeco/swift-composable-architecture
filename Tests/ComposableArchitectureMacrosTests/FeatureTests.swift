import ComposableArchitectureMacros
import MacroTesting
import XCTest

final class FeatureTests: MacroBaseTestCase {
  func testBasics() {
    assertMacro {
      #"""
      store.scope(#feature(\.child))
      """#
    } matches: {
      #"""
      store.scope(ComposableArchitecture.Feature(
        state: \.child,
        action: {
            .child($0)
        }
      ))
      """#
    }
  }

  func testCompound() {
    assertMacro {
      #"""
      store.scope(#feature(\.child.grandchild))
      """#
    } matches: {
      #"""
      store.scope(ComposableArchitecture.Feature(
        state: \.child.grandchild,
        action: {
            .grandchild(.child($0))
        }
      ))
      """#
    }
  }

  func testPresentation() {
    assertMacro {
      #"""
      store.scope(#feature(\.destination?.sheet))
      """#
    } matches: {
      #"""
      store.scope(ComposableArchitecture.Feature(
        state: \.destination?.sheet,
        action: {
            .destination($0.presented { .sheet($0) })
        }
      ))
      """#
    }
  }
}
