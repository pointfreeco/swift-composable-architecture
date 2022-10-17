import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class NavigationSheetTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: SheetDemo.State(),
      reducer: SheetDemo()
    )

    let mainQueue = DispatchQueue.test
    store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()

    await store.send(.sheet(.present(.animations(Animations.State())))) {
      $0.sheet = .animations(Animations.State())
    }
    await store.send(.sheet(.presented(.animations(.rainbowButtonTapped))))
    await store.receive(.sheet(.presented(.animations(.setColor(.red))))) {
      try (/Optional.some).appending(path: /SheetDemo.Destinations.State.animations)
        .modify(&$0.sheet) { $0.circleColor = .red }
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.sheet(.presented(.animations(.setColor(.blue))))) {
      try (/Optional.some).appending(path: /SheetDemo.Destinations.State.animations)
        .modify(&$0.sheet) { $0.circleColor = .blue }
    }

    await store.send(.sheet(.dismiss)) {
      $0.sheet = nil
    }
  }
}
