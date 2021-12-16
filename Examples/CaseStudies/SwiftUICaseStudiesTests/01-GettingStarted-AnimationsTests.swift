import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class AnimationTests: XCTestCase {
  let scheduler = DispatchQueue.test

  func testRainbow() {
    let store = TestStore(
      initialState: AnimationsState(),
      reducer: animationsReducer,
      environment: AnimationsEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.rainbowButtonTapped)

    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .red
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .blue
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .green
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .orange
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .pink
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .purple
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .yellow
    }

    self.scheduler.advance(by: .seconds(1))
    store.receive(/AnimationsAction.setColor) {
      $0.circleColor = .white
    }

    self.scheduler.run()
  }
}
