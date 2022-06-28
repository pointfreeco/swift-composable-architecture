import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class AnimationTests: XCTestCase {
  func testRainbow() {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: AnimationsState(),
      reducer: animationsReducer,
      environment: AnimationsEnvironment(
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.rainbowButtonTapped)

    store.receive(.setColor(.red)) {
      $0.circleColor = .red
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.blue)) {
      $0.circleColor = .blue
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.green)) {
      $0.circleColor = .green
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.orange)) {
      $0.circleColor = .orange
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.pink)) {
      $0.circleColor = .pink
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.purple)) {
      $0.circleColor = .purple
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.yellow)) {
      $0.circleColor = .yellow
    }

    mainQueue.advance(by: .seconds(1))
    store.receive(.setColor(.white)) {
      $0.circleColor = .white
    }

    mainQueue.run()
  }
}
