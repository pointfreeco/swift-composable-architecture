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

    await store.send(.animations(.present(Animations.State()))) {
      $0.animations = Animations.State()
    }
    await store.send(.animations(.presented(.rainbowButtonTapped)))
    await store.receive(.animations(.presented(.setColor(.red)))) {
      try (/Optional.some).modify(&$0.animations) {
        $0.circleColor = .red
      }
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.animations(.presented(.setColor(.blue)))) {
      try (/Optional.some).modify(&$0.animations) {
        $0.circleColor = .blue
      }
    }

    await store.send(.animations(.dismiss)) {
      $0.animations = nil
    }
  }
}
