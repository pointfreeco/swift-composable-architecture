#if DEBUG
  import XCTest

  @testable import ComposableArchitecture

  @MainActor
  final class BindingLocalTests: BaseTCATestCase {
    public func testBindingLocalIsActive() {
      XCTAssertFalse(BindingLocal.isActive)

      struct MyReducer: ReducerProtocol {
        struct State: Equatable {
          var text = ""
        }

        enum Action: Equatable {
          case textChanged(String)
        }

        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case let .textChanged(text):
            state.text = text
            return .none
          }
        }
      }

      let store = Store(initialState: MyReducer.State()) { MyReducer() }
      let viewStore = ViewStore(store, observe: { $0 })

      let binding = viewStore.binding(get: \.text) { text in
        XCTAssertTrue(BindingLocal.isActive)
        return .textChanged(text)
      }
      binding.wrappedValue = "Hello!"
      XCTAssertEqual(viewStore.text, "Hello!")
    }
  }
#endif
