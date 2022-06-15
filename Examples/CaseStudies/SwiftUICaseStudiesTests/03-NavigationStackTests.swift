import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class NavigationStackTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testBasics() async {
    let store = _TestStore(
      initialState: .init(),
      reducer: NavigationStackDemo()
        .dependency(\.factClient.fetch) { "\($0) is a good number." }
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    // Push Screen A, increment and fetch fact.
    let screenAID = store.reducer.nextID()
    store.send(.navigation(.setPath([.init(id: screenAID, element: .screenA(.init()))]))) {
      $0.path.append(.init(id: screenAID, element: .screenA(.init())))
    }
    store.send(.navigation(.element(id: screenAID, .screenA(.incrementButtonTapped)))) {
      try CasePath(NavigationStackDemo.State.Route.screenA).unwrapModify(&$0.path[id: screenAID]) {
        $0.count = 1
      }
      $0.total = 1
    }
    store.send(.navigation(.element(id: screenAID, .screenA(.factButtonTapped)))) {
      try CasePath(NavigationStackDemo.State.Route.screenA).unwrapModify(&$0.path[id: screenAID]) {
        $0.isLoading = true
      }
    }
    await self.scheduler.advance()
    await store.receive(.navigation(.element(id: screenAID, .screenA(.factResponse(.success("1 is a good number.")))))) {
      try CasePath(NavigationStackDemo.State.Route.screenA).unwrapModify(&$0.path[id: screenAID]) {
        $0.isLoading = false
        $0.fact = "1 is a good number."
      }
    }

    // Push Screen C, start timer, wait 2 seconds
    let screenCID = store.reducer.nextID()
    store.send(.navigation(.setPath(store.state.path + [.init(id: screenCID, element: .screenC(.init()))]))) {
      $0.path.append(.init(id: screenCID, element: .screenC(.init())))
    }
    store.send(.navigation(.element(id: screenCID, .screenC(.startButtonTapped))))
    await self.scheduler.advance(by: .seconds(2))
    await store.receive(.navigation(.element(id: screenCID, .screenC(.timerTick)))) {
      try CasePath(NavigationStackDemo.State.Route.screenC).unwrapModify(&$0.path[id: screenCID]) {
        $0.count = 1
      }
      $0.total = 2
    }
    await store.receive(.navigation(.element(id: screenCID, .screenC(.timerTick)))) {
      try CasePath(NavigationStackDemo.State.Route.screenC).unwrapModify(&$0.path[id: screenCID]) {
        $0.count = 2
      }
      $0.total = 3
    }

    // Pop screen C off stack
    store.send(.navigation(.setPath(store.state.path.dropLast()))) {
      $0.path.removeLast()
      $0.total = 1
    }
  }

  func testProgrammaticNavigation() {
    let store = _TestStore(
      initialState: .init(),
      reducer: NavigationStackDemo()
        .dependency(\.factClient.fetch) { "\($0) is a good number." }
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    let screenBID = store.reducer.nextID()
    store.send(.navigation(.setPath([.init(id: screenBID, element: .screenB(.init()))]))) {
      $0.path = [.init(id: screenBID, element: .screenB(.init()))]
    }

    store.send(.navigation(.element(id: screenBID, .screenB(.screenAButtonTapped)))) {
      $0.path.append(.init(id: 1, element: .screenA(.init())))
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
