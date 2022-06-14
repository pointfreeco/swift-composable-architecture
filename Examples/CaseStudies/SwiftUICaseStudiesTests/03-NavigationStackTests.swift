import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class NavigationStackTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testBasics() {
    let store = TestStore(
      initialState: .init(),
      reducer: navigationStackReducer,
      environment: .init(
        fact: .init(fetch: { Effect(value: "\($0) is a good number.") }),
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        nextId: Int.incrementing
      )
    )

    // Push Screen A, increment and fetch fact.
    store.send(.navigation(.setPath([.init(id: 0, element: .screenA(.init()))]))) {
      $0.path.append(.init(id: 0, element: .screenA(.init())))
    }
    store.send(.navigation(.element(id: 0, .screenA(.incrementButtonTapped)))) {
      try CasePath(NavigationStackState.Route.screenA).unwrapModify(&$0.path[id: 0]) {
        $0.count = 1
      }
      $0.total = 1
    }
    store.send(.navigation(.element(id: 0, .screenA(.factButtonTapped)))) {
      try CasePath(NavigationStackState.Route.screenA).unwrapModify(&$0.path[id: 0]) {
        $0.isLoading = true
      }
    }
    self.scheduler.advance()
    store.receive(.navigation(.element(id: 0, .screenA(.factResponse(.success("1 is a good number.")))))) {
      try CasePath(NavigationStackState.Route.screenA).unwrapModify(&$0.path[id: 0]) {
        $0.isLoading = false
        $0.fact = "1 is a good number."
      }
    }

    // Push Screen C, start timer, wait 2 seconds, pop off stack.
    let id = UUID()
    store.send(.navigation(.setPath(store.state.path + [.init(id: 1, element: .screenC(.init(id: id)))]))) {
      $0.path.append(.init(id: 1, element: .screenC(.init(id: id))))
    }
    store.send(.navigation(.element(id: 1, .screenC(.startButtonTapped))))
    self.scheduler.advance(by: .seconds(2))
    store.receive(.navigation(.element(id: 1, .screenC(.timerTick)))) {
      try CasePath(NavigationStackState.Route.screenC).unwrapModify(&$0.path[id: 1]) {
        $0.count = 1
      }
      $0.total = 2
    }
    store.receive(.navigation(.element(id: 1, .screenC(.timerTick)))) {
      try CasePath(NavigationStackState.Route.screenC).unwrapModify(&$0.path[id: 1]) {
        $0.count = 2
      }
      $0.total = 3
    }

    store.send(.navigation(.setPath(store.state.path.dropLast()))) {
      $0.path.removeLast()
      $0.total = 1
    }
  }
}

// TODO: move to swift-case-paths?
extension CasePath {
  public func unwrapModify<Result>(
    _ root: inout Optional<Root>,
    _ body: (inout Value) throws -> Result
  ) throws -> Result {
    return try CasePath<Root?, Root>(Optional.some).appending(path: self).modify(&root, body)
  }
}
