import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class NavigationStackTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testBasics() async {
    let store = TestStore(
      initialState: .init(),
      reducer: NavigationDemo()
        .dependency(\.factClient.fetch) { "\($0) is a good number." }
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    // Push Screen A, increment and fetch fact.
    let screenAID = store.dependencies.navigationID.next()
    await store.send(.path(.setPath([screenAID: .screenA(.init())]))) {
      $0.$path = [screenAID: .screenA(.init())]
    }
    await store.send(.path(.element(id: screenAID, .screenA(.incrementButtonTapped)))) {
      try CasePath(NavigationDemo.Destinations.State.screenA).unwrapModify(&$0.$path[id: screenAID]) {
        $0.count = 1
      }
    }
    await store.send(.path(.element(id: screenAID, .screenA(.factButtonTapped)))) {
      try CasePath(NavigationDemo.Destinations.State.screenA).unwrapModify(&$0.$path[id: screenAID]) {
        $0.isLoading = true
      }
    }
    await self.scheduler.advance()
    await store.receive(.path(.element(id: screenAID, .screenA(.factResponse(.success("1 is a good number.")))))) {
      try CasePath(NavigationDemo.Destinations.State.screenA).unwrapModify(&$0.$path[id: screenAID]) {
        $0.isLoading = false
        $0.fact = "1 is a good number."
      }
    }

    // Push Screen C, start timer, wait 2 seconds
    let screenCID = store.dependencies.navigationID.next()
    await store.send(.path(.setPath(store.state.$path + [screenCID: .screenC(.init())]))) {
      $0.$path.append(.init(id: screenCID, element: .screenC(.init())))
    }
    await store.send(.path(.element(id: screenCID, .screenC(.startButtonTapped)))) {
      try CasePath(NavigationDemo.Destinations.State.screenC).unwrapModify(&$0.$path[id: screenCID]) {
        $0.isTimerRunning = true
      }
    }
    await self.scheduler.advance(by: .seconds(2))
    await store.receive(.path(.element(id: screenCID, .screenC(.timerTick)))) {
      try CasePath(NavigationDemo.Destinations.State.screenC).unwrapModify(&$0.$path[id: screenCID]) {
        $0.count = 1
      }
    }
    await store.receive(.path(.element(id: screenCID, .screenC(.timerTick)))) {
      try CasePath(NavigationDemo.Destinations.State.screenC).unwrapModify(&$0.$path[id: screenCID]) {
        $0.count = 2
      }
    }

    // Pop screen C off stack
    var path = store.state.$path
    path.removeLast()
    await store.send(.path(.setPath(path))) {
      $0.path.removeLast()
    }
  }

  func testProgrammaticNavigation() async {
    let store = TestStore(
      initialState: .init(),
      reducer: NavigationDemo()
        .dependency(\.factClient.fetch) { "\($0) is a good number." }
        .dependency(\.mainQueue, self.scheduler.eraseToAnyScheduler())
    )

    let screenBID = store.dependencies.navigationID.next()
    await store.send(.path(.setPath([screenBID: .screenB(.init())]))) {
      $0.$path = [screenBID: .screenB(.init())]
    }

    await store.send(.path(.element(id: screenBID, .screenB(.screenAButtonTapped)))) {
      $0.$path.append(.init(id: 1, element: .screenA(.init())))
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
