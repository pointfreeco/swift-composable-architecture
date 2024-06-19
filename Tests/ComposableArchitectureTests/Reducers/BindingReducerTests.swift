import ComposableArchitecture
import XCTest

final class BindingTests: BaseTCATestCase {
  @Reducer
  struct BindingTest {
    struct State: Equatable {
      @BindingState var nested = Nested()

      struct Nested: Equatable {
        var field = ""
      }
    }

    enum Action: BindableAction, Equatable {
      case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
      BindingReducer()
      Reduce { state, action in
        switch action {
        case .binding(.set(\.$nested, State.Nested(field: "special"))):
          state.nested.field += "*"
          return .none
        case .binding(\.$nested):
          state.nested.field += "!"
          return .none
        case .binding:
          return .none
        }
      }
    }
  }

  func testEquality() {
    struct State {
      @BindingState var count = 0
    }
    XCTAssertEqual(
      BindingAction<State>.set(\.$count, 1),
      BindingAction<State>.set(\.$count, 1)
    )
    XCTAssertNotEqual(
      BindingAction<State>.set(\.$count, 1),
      BindingAction<State>.set(\.$count, 2)
    )
  }

  @MainActor
  func testViewEquality() {
    struct Feature: Reducer {
      struct State: Equatable {
        @BindingState var count = 0
      }
      enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
      }
      var body: some ReducerOf<Self> {
        BindingReducer()
      }
    }
    struct ViewState: Equatable {
      @BindingViewState var count: Int
    }
    let store = Store(initialState: Feature.State()) {
      Feature()
    }
    let viewStore = ViewStore(store, observe: { ViewState(count: $0.$count) })
    let initialState = viewStore.state
    let count = viewStore.$count
    count.wrappedValue += 1
    XCTAssertNotEqual(initialState, viewStore.state)

    XCTAssertEqual(count.wrappedValue, 1)
  }

  @MainActor
  func testNestedBindingState() {
    let store = Store(initialState: BindingTest.State()) { BindingTest() }

    let viewStore = ViewStore(store, observe: { $0 })

    viewStore.$nested.field.wrappedValue = "Hello"

    XCTAssertEqual(viewStore.state, .init(nested: .init(field: "Hello!")))
  }

  @MainActor
  func testNestedBindingViewState() {
    struct ViewState: Equatable {
      @BindingViewState var field: String
    }

    let store = Store(initialState: BindingTest.State()) { BindingTest() }

    let viewStore = ViewStore(store, observe: { ViewState(field: $0.$nested.field) })

    viewStore.$field.wrappedValue = "Hello"

    XCTAssertEqual(store.withState { $0.nested.field }, "Hello!")
  }

  @MainActor
  func testBindingActionUpdatesRespectsPatternMatching() async {
    let testStore = TestStore(
      initialState: BindingTest.State(nested: BindingTest.State.Nested(field: ""))
    ) {
      BindingTest()
    }

    await testStore.send(.binding(.set(\.$nested, BindingTest.State.Nested(field: "special")))) {
      $0.nested = BindingTest.State.Nested(field: "special*")
    }
    await testStore.send(.binding(.set(\.$nested, BindingTest.State.Nested(field: "Hello")))) {
      $0.nested = BindingTest.State.Nested(field: "Hello!")
    }
  }

  struct TestMatching {
    struct CounterState {
      @BindingState var count = 0
    }
    @CasePathable
    enum CounterAction: CasePathable {
      case binding(BindingAction<CounterState>)
    }
  }
  func testMatching() {
    let action = TestMatching.CounterAction.binding(.set(\.$count, 42))
    XCTAssertEqual(action[case: \.binding.$count], 42)
  }
}
