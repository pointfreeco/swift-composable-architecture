import CasePaths
import XCTest

@testable import ComposableArchitecture

enum IntKey: DependencyKey {
  static let defaultValue = -1
  static let testValue = 0
}
extension DependencyValues {
  var int: Int {
    get { self[IntKey.self] }
    set { self[IntKey.self] = newValue }
  }
}

final class _ReducerTests: XCTestCase {
  func testEnvironment() {
    struct AppReducer: _Reducer {
      @Dependency(\.mainQueue) var mainQueue
      @Dependency(\.int) var int

      struct State {
        var count = 0
        var child1 = Child1Reducer.State()
      }
      enum Action {
        case decr, incr
        case child1(Child1Reducer.Action)
      }

      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        print("AppReducer.int", self.int)
        self.mainQueue.schedule(after: .init(.now()+10)) {
          print("AppReducer HI!")
        }
        switch action {
        case .decr:
          state.count -= 1
          return .none
        case .incr:
          state.count += 1
          return .none
        case .child1:
          return .none
        }
      }
    }

    struct Child1Reducer: _Reducer {
      @Dependency(\.mainQueue) var mainQueue
      @Dependency(\.int) var int

      enum Action {
        case decr, incr
      }
      func reduce(into state: inout Int, action: Action) -> Effect<Action, Never> {
        print("Child1Reducer.int", self.int)
        self.mainQueue.schedule(after: .init(.now()+10)) {
          print("Child1Reducer HI!")
        }
        switch action {
        case .decr:
          state -= 1
          return .none
        case .incr:
          state += 1
          return .none
        }
      }
    }

    let appReducer = AppReducer()
      .combined(
        with: Child1Reducer()
          .pullback(state: \.child1, action: /AppReducer.Action.child1)
          .dependency(\.int, 1729)
      )
      .dependency(\.mainQueue, .immediate)
      .dependency(\.int, 42)

    var state = AppReducer.State()
    _ = appReducer.reduce(into: &state, action: .incr)
    _ = appReducer.reduce(into: &state, action: .decr)
    _ = appReducer.reduce(into: &state, action: .child1(.incr))
    _ = appReducer.reduce(into: &state, action: .child1(.decr))
  }
}
