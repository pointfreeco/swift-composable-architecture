import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class NavigationSheetTests: XCTestCase {
  func testBasics() async {
    let clock = TestClock()
    let store = TestStore(
      initialState: SheetDemo.State(),
      reducer: SheetDemo()
    ) {
      $0.continuousClock = clock
    }

    let mainQueue = DispatchQueue.test
    store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()

    await store.send(.animationsButtonTapped) {
      $0.destination = .animations(Animations.State())
    }
    await store.send(.destination(.presented(.animations(.rainbowButtonTapped))))
    await store.receive(.destination(.presented(.animations(.setColor(.red))))) {
      try (/Optional.some).appending(path: /SheetDemo.Destinations.State.animations)
        .modify(&$0.destination) { $0.circleColor = .red }
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.destination(.presented(.animations(.setColor(.blue))))) {
      try (/Optional.some).appending(path: /SheetDemo.Destinations.State.animations)
        .modify(&$0.destination) { $0.circleColor = .blue }
    }

    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }
}
