import ComposableArchitecture
import XCTest

@MainActor
final class BindingTests: XCTestCase {
  #if swift(>=5.7)
    func testNestedBindingStateWithNestedMatching() {
      struct BindingTest: ReducerProtocol {
        struct State: BindableStateProtocol, Equatable {
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

      let viewStore = ViewStore(store)

      XCTAssertNoDifference(viewStore.state, .init(nested: .init(field: "")))
      viewStore.$nested.field.wrappedValue = "Hello"
      // Pattern matching with nested `KeyPath`s is not supported anymore, so the following should
      // now fail:
      XCTExpectFailure {
        XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
      }
      XCTAssertNoDifference(viewStore.state, .init(nested: .init(field: "Hello")))
    }

    func testBindingState() {
      struct BindingTest: ReducerProtocol {
        struct State: BindableStateProtocol, Equatable {
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
            case .binding(\.$nested):
              state.nested.field += "!"
              return .none
            default:
              return .none
            }
          }
        }
      }

      let store = Store(initialState: BindingTest.State(), reducer: BindingTest())

      let viewStore = ViewStore(store)

      viewStore.$nested.field.wrappedValue = "Hello"
      XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
    }
  #endif
}
