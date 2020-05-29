import ComposableArchitecture
import XCTest

class MyTests: XCTestCase {
  func testThing() {
    struct State: Equatable {
      var data: IdentifiedArrayOf<Child>
    }

    struct Child: Equatable, Identifiable {
      let id: Int
      var value: Int
    }

    enum Action {
      case removeAll
      case child(id: Int, action: ChildAction)
    }

    enum ChildAction {
      case start
      case setValue(Int)
    }

    let childReducer = Reducer<Child, ChildAction, Void> { state, action, _ in
      switch action {
      case .start:
        return Effect(value: .setValue(10))
          .delay(for: 5, scheduler: DispatchQueue.main)
          .eraseToEffect()

      case .setValue(let value):
        state.value = value
        return .none
      }
    }

    let appReducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .removeAll:
        state.data = []
        return .none
      case .child:
        return .none
      }
    }
    .combined(with: childReducer.forEach(state: \.data, action: /Action.child, environment: { () }))


    let store = Store(
      initialState: State(data: [Child(id: 1, value: 1)]),
      reducer: appReducer.debug(),
      environment: ()
    )

    let viewStore = ViewStore(store)

    viewStore.send(.child(id: 1, action: .start))
    viewStore.send(.removeAll)
    // *crash* after 5 seconds

    XCTWaiter.wait(for: [.init()], timeout: 10)
  }
}
