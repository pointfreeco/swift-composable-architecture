import ComposableArchitecture
import XCTest

@MainActor
final class BindingTests: XCTestCase {
  #if swift(>=5.7)
    func testNestedBindableState() {
      struct BindingTest: ReducerProtocol {
        struct State: Equatable {
          @BindableState var nested = Nested()

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

      viewStore.binding(\.$nested.field).wrappedValue = "Hello"

      XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
    }
    
    func testNestedBindableViewState() {
        struct BindingTest: ReducerProtocol {
          struct State: Equatable {
            @BindableState var nested = Nested()

            struct Nested: Equatable {
              var field = ""
            }
              
            // Usually should be placed in an extension
            var viewState: ViewState {
                get { .init(nestedField: self.nested.field) }
                set { self.nested.field = newValue.nestedField }
            }
          }

          enum Action: BindableAction, Equatable {
            case binding(BindingAction<State>)
            
            // Usually should be placed in an extension
            static func action(from viewAction: ViewAction) -> Self {
              switch viewAction {
                case let .binding(action):
                  return .binding(action.pullback(\.viewState))
              }
            }
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
        
        struct ViewState: Equatable {
            @BindableViewState(\BindingTest.State.$nested.field) var nestedField = BindingTest.State.Nested().field
        }
        
        enum ViewAction: Equatable, BindableViewAction {
          case binding(BindingViewAction<ViewState, BindingTest.State>)
        }
        
        let store = Store(initialState: BindingTest.State(), reducer: BindingTest())

        let viewStore = ViewStore(store, observe: \.viewState, send: BindingTest.Action.action(from:))

        viewStore.binding(\.$nestedField).wrappedValue = "Hello"

        XCTAssertEqual(viewStore.state, .init(nestedField: "Hello!"))
        XCTAssertEqual(ViewStore(store).state, BindingTest.State(nested: .init(field: "Hello!")))
    }
  #endif
}
