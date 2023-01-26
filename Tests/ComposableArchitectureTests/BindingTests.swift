import ComposableArchitecture
import XCTest

@MainActor
final class BindingTests: XCTestCase {
  #if swift(>=5.7)
    func testNestedBindingState() {
      struct BindingTest: ReducerProtocol {
        struct State: Equatable {
          @BindingState var nested = Nested()

          struct Nested: Equatable {
            var field = ""
          }
        }

        enum Action: BindableAction, Equatable {
          case binding(BindingAction<State>)
        }

        var body: some ReducerProtocol<State, Action> {
          BindingReducer()
          Reduce { state, action in
            switch action {
            case .binding(\.$nested.field):
              state.nested.field += "!"
              return .none
            default:
              return .none
            }
          }
        }
      }

      let store = Store(initialState: BindingTest.State(), reducer: BindingTest())

      let viewStore = ViewStore(store, observe: { $0 })

      viewStore.binding(\.$nested.field).wrappedValue = "Hello"

      XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
    }
  #endif
}
