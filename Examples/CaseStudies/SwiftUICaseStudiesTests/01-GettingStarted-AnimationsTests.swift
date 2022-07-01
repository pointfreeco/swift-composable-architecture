import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class AnimationTests: XCTestCase {
  func testRainbow() async {
    let mainQueue = DispatchQueue.test

    let store = TestStore(
      initialState: AnimationsState(),
      reducer: animationsReducer,
      environment: AnimationsEnvironment(
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )

    store.send(.rainbowButtonTapped)

    await store.receive(.setColor(.red)) {
      $0.circleColor = .red
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.blue)) {
      $0.circleColor = .blue
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.green)) {
      $0.circleColor = .green
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.orange)) {
      $0.circleColor = .orange
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.pink)) {
      $0.circleColor = .pink
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.purple)) {
      $0.circleColor = .purple
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.yellow)) {
      $0.circleColor = .yellow
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.white)) {
      $0.circleColor = .white
    }

    await mainQueue.run()
  }
}
