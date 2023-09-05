import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class WithViewStoreTests: MacroBaseTestCase {
  func testMacro_Improved() {
    assertMacro {
      #"""
      @WithViewStore(for: Feature.self)
      struct FeatureView: View {
        let store: StoreOf<Feature>

        var body: some View {
          VStack {
            Text("\(store.count)")
            Button("+") {
              send(.incrementButtonTapped)
            }
          }
        }
        func tap() {
          send(.tap)
        }
      }
      """#
    } matches: {
      #"""
      struct FeatureView: View {
        let store: StoreOf<Feature>

        var body: some View {
          VStack {
            Text("\(store.count)")
            Button("+") {
              send(.incrementButtonTapped)
            }
          }
        }
        func tap() {
          send(.tap)
        }

        func send(_ action: Feature.Action.View) {
          self.store.send(.view(action))
        }
      }
      """#
    }
  }

  func testMacroNoStoreVariable() {
    assertMacro {
      """
      @WithViewStore(for: Feature.self)
      struct FeatureView: View {
        var body: some View {
          EmptyView()
        }
      }
      """
    } matches: {
      """
      @WithViewStore(for: Feature.self)
      ┬────────────────────────────────
      ╰─ 🛑 @WithViewStore macro requires 'FeatureView' to have a 'store' property of type 'Store'.
      struct FeatureView: View {
        var body: some View {
          EmptyView()
        }
      }
      """
    }
  }

  func testWarningWithDirectStoreDotSend() {
    assertMacro {
      """
      @WithViewStore(for: Feature.self)
      struct FeatureView: View {
        let store: StoreOf<Feature>

        var body: some View {
          Button("+") {
            store.send(.incrementButtonTapped)
          }
        }
        func tap() {
          self.store.send(.tap)
        }
      }
      """
    } matches: {
      """
      @WithViewStore(for: Feature.self)
      struct FeatureView: View {
        let store: StoreOf<Feature>

        var body: some View {
          Button("+") {
            store.send(.incrementButtonTapped)
            ┬─────────
            ╰─ ⚠️ Do not use 'store.send' directly when using @WithViewStore. Instead, use 'send'.
          }
        }
        func tap() {
          self.store.send(.tap)
          ┬──────────────
          ╰─ ⚠️ Do not use 'store.send' directly when using @WithViewStore. Instead, use 'send'.
        }
      }
      """
    }
  }
}
