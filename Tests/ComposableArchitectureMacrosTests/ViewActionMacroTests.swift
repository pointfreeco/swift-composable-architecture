#if canImport(ComposableArchitectureMacros)
import ComposableArchitectureMacros
import MacroTesting
import XCTest

final class ViewActionMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      //isRecording: true,
      macros: [ViewActionMacro.self]
    ) {
      super.invokeTest()
    }
  }

  func testLetStore() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        let store: StoreOf<Feature>
        var body: some View {
          EmptyView()
        }
      }
      """
    } expansion: {
      """
      struct FeatureView: View {
        let store: StoreOf<Feature>
        var body: some View {
          EmptyView()
        }

        @discardableResult
        fileprivate func send(_ action: Feature.Action.View) -> StoreTask {
          store.send(.view(action))
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, animation: Animation?) -> StoreTask {
          store.send(.view(action), animation: animation)
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, transaction: Transaction) -> StoreTask {
          store.send(.view(action), transaction: transaction)
        }
      }
      """
    }
  }

  func testStateStore() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        @State var store: StoreOf<Feature>
        var body: some View {
          EmptyView()
        }
      }
      """
    } expansion: {
      """
      struct FeatureView: View {
        @State var store: StoreOf<Feature>
        var body: some View {
          EmptyView()
        }

        @discardableResult
        fileprivate func send(_ action: Feature.Action.View) -> StoreTask {
          store.send(.view(action))
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, animation: Animation?) -> StoreTask {
          store.send(.view(action), animation: animation)
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, transaction: Transaction) -> StoreTask {
          store.send(.view(action), transaction: transaction)
        }
      }
      """
    }
  }

  func testStateStore_WithDefault() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        @State var store = Store(initialState: Feature.State()) {
          Feature()
        }
        var body: some View {
          EmptyView()
        }
      }
      """
    } expansion: {
      """
      struct FeatureView: View {
        @State var store = Store(initialState: Feature.State()) {
          Feature()
        }
        var body: some View {
          EmptyView()
        }

        @discardableResult
        fileprivate func send(_ action: Feature.Action.View) -> StoreTask {
          store.send(.view(action))
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, animation: Animation?) -> StoreTask {
          store.send(.view(action), animation: animation)
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, transaction: Transaction) -> StoreTask {
          store.send(.view(action), transaction: transaction)
        }
      }
      """
    }
  }

  func testBindableStore() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        @Bindable var store: StoreOf<Feature>
        var body: some View {
          EmptyView()
        }
      }
      """
    } expansion: {
      """
      struct FeatureView: View {
        @Bindable var store: StoreOf<Feature>
        var body: some View {
          EmptyView()
        }

        @discardableResult
        fileprivate func send(_ action: Feature.Action.View) -> StoreTask {
          store.send(.view(action))
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, animation: Animation?) -> StoreTask {
          store.send(.view(action), animation: animation)
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, transaction: Transaction) -> StoreTask {
          store.send(.view(action), transaction: transaction)
        }
      }
      """
    }
  }

  func testNoStore() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var body: some View {
          EmptyView()
        }
      }
      """
    } diagnostics: {
      """
      @ViewAction(for: Feature.self)
      ╰─ 🛑 @ViewAction macro requires 'FeatureView'  to have a 'store' property of type 'Store'.
      struct FeatureView: View {
        var body: some View {
          EmptyView()
        }
      }
      """
    }
  }

  func testWarning_StoreSend() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { store.send(.tap) }
        }
      }
      """
    } diagnostics: {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { store.send(.tap) }
                          ┬─────────
                          ╰─ ⚠️ Do not use 'store.send' directly when using @ViewAction. Instead, use 'send'.
                             ✏️ Use 'send'
        }
      }
      """
    }fixes: {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { send}
        }
      }
      """
    }expansion: {
      """
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { send}
        }

        @discardableResult
        fileprivate func send(_ action: Feature.Action.View) -> StoreTask {
          store.send(.view(action))
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, animation: Animation?) -> StoreTask {
          store.send(.view(action), animation: animation)
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, transaction: Transaction) -> StoreTask {
          store.send(.view(action), transaction: transaction)
        }
      }
      """
    }
  }

  func testWarning_SelfStoreSend() {
    assertMacro {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { self.store.send(.tap) }
        }
      }
      """
    } diagnostics: {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { self.store.send(.tap) }
                          ┬──────────────
                          ╰─ ⚠️ Do not use 'self.store.send' directly when using @ViewAction. Instead, use 'self.send'.
                             ✏️ Use 'self.send'
        }
      }
      """
    }fixes: {
      """
      @ViewAction(for: Feature.self)
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { self.send}
        }
      }
      """
    }expansion: {
      """
      struct FeatureView: View {
        var store: StoreOf<Feature>
        var body: some View {
          Button("Tap") { self.send}
        }

        @discardableResult
        fileprivate func send(_ action: Feature.Action.View) -> StoreTask {
          store.send(.view(action))
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, animation: Animation?) -> StoreTask {
          store.send(.view(action), animation: animation)
        }
        @discardableResult
        fileprivate func send(_ action: Feature.Action.View, transaction: Transaction) -> StoreTask {
          store.send(.view(action), transaction: transaction)
        }
      }
      """
    }
  }
}
#endif
