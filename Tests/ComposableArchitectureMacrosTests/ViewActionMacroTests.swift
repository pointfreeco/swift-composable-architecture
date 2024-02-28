#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import XCTest

  final class ViewActionMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        // isRecording: true,
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
        ╰─ 🛑 '@ViewAction' requires 'FeatureView' to have a 'store' property of type 'Store'.
           ✏️ Add 'store'
        struct FeatureView: View {
          var body: some View {
            EmptyView()
          }
        }
        """
      } fixes: {
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

    func testNoStore_Public() {
      assertMacro {
        """
        @ViewAction(for: Feature.self)
        public struct FeatureView: View {
          public var body: some View {
            EmptyView()
          }
        }
        """
      } diagnostics: {
        """
        @ViewAction(for: Feature.self)
        ╰─ 🛑 '@ViewAction' requires 'FeatureView' to have a 'store' property of type 'Store'.
           ✏️ Add 'store'
        public struct FeatureView: View {
          public var body: some View {
            EmptyView()
          }
        }
        """
      } fixes: {
        """
        @ViewAction(for: Feature.self)
        public struct FeatureView: View {
          public let store: StoreOf<Feature>

          public var body: some View {
            EmptyView()
          }
        }
        """
      } expansion: {
        """
        public struct FeatureView: View {
          public let store: StoreOf<Feature>

          public var body: some View {
            EmptyView()
          }
        }

        extension FeatureView: ComposableArchitecture.ViewActionSending {
        }
        """
      }
    }

    func testNoStore_Package() {
      assertMacro {
        """
        @ViewAction(for: Feature.self)
        package struct FeatureView: View {
          package var body: some View {
            EmptyView()
          }
        }
        """
      } diagnostics: {
        """
        @ViewAction(for: Feature.self)
        ╰─ 🛑 '@ViewAction' requires 'FeatureView' to have a 'store' property of type 'Store'.
           ✏️ Add 'store'
        package struct FeatureView: View {
          package var body: some View {
            EmptyView()
          }
        }
        """
      } fixes: {
        """
        @ViewAction(for: Feature.self)
        package struct FeatureView: View {
          package let store: StoreOf<Feature>

          package var body: some View {
            EmptyView()
          }
        }
        """
      } expansion: {
        """
        package struct FeatureView: View {
          package let store: StoreOf<Feature>

          package var body: some View {
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
                            ┬───────────────
                            ╰─ ⚠️ Do not use 'store.send' directly when using '@ViewAction'
          }
        }
        """
      } expansion: {
        """
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { store.send(.tap) }
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
                            ┬────────────────────
                            ╰─ ⚠️ Do not use 'store.send' directly when using '@ViewAction'
          }
        }
        """
      } expansion: {
        """
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { self.store.send(.tap) }
          }
        }

        extension FeatureView: ComposableArchitecture.ViewActionSending {
        }
        """
      }
    }

    func testWarning_StoreSend_ViewAction() {
      assertMacro {
        """
        @ViewAction(for: Feature.self)
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { store.send(.view(.tap)) }
          }
        }
        """
      } diagnostics: {
        """
        @ViewAction(for: Feature.self)
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { store.send(.view(.tap)) }
                            ┬──────────────────────
                            ╰─ ⚠️ Do not use 'store.send' directly when using '@ViewAction'
                               ✏️ Call 'send' directly with a view action
          }
        }
        """
      } fixes: {
        """
        @ViewAction(for: Feature.self)
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { send(.tap) }
          }
        }
        """
      } expansion: {
        """
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { send(.tap) }
          }
        }

        extension FeatureView: ComposableArchitecture.ViewActionSending {
        }
        """
      }
    }

    func testWarning_SelfStoreSend_ViewAction() {
      assertMacro {
        """
        @ViewAction(for: Feature.self)
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { self.store.send(.view(.tap)) }
          }
        }
        """
      } diagnostics: {
        """
        @ViewAction(for: Feature.self)
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { self.store.send(.view(.tap)) }
                            ┬───────────────────────────
                            ╰─ ⚠️ Do not use 'store.send' directly when using '@ViewAction'
                               ✏️ Call 'send' directly with a view action
          }
        }
        """
      } fixes: {
        """
        @ViewAction(for: Feature.self)
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { self.send(.tap) }
          }
        }
        """
      } expansion: {
        """
        struct FeatureView: View {
          var store: StoreOf<Feature>
          var body: some View {
            Button("Tap") { self.send(.tap) }
          }
        }

        extension FeatureView: ComposableArchitecture.ViewActionSending {
        }
        """
      }
    }

    func testAvailability() {
      assertMacro {
        """
        @available(iOS 17, macOS 14, tvOS 17, visionOS 1, watchOS 10, *)
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
        @available(iOS 17, macOS 14, tvOS 17, visionOS 1, watchOS 10, *)
        struct FeatureView: View {
          @State var store: StoreOf<Feature>
          var body: some View {
            EmptyView()
          }
        }

        @available(iOS 17, macOS 14, tvOS 17, visionOS 1, watchOS 10, *) extension FeatureView: ComposableArchitecture.ViewActionSending {
        }
        """
      }
    }
  }
#endif
