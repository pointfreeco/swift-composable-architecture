#if canImport(ComposableArchitectureMacros)
import ComposableArchitectureMacros
import MacroTesting
import XCTest

final class ViewActionMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      isRecording: true,
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
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
         ✏️ Add 'store'
      struct FeatureView: View {
        var body: some View {
          EmptyView()
        }
      }
      """
    }fixes: {
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
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
      }

      extension FeatureView: ComposableArchitecture.ViewActionSending {
      }
      """
    }
  }
}
#endif
