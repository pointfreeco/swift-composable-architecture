import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class AnimationTests: XCTestCase {
  let scheduler = DispatchQueue.test

  @MainActor
  func testRainbow() async {
    let store = TestStore(
      initialState: AnimationsState(),
      reducer: animationsReducer,
      environment: AnimationsEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.rainbowButtonTapped)

    await store.receive(.setColor(.red)) {
      $0.circleColor = .red
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.blue)) {
      $0.circleColor = .blue
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.green)) {
      $0.circleColor = .green
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.orange)) {
      $0.circleColor = .orange
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.pink)) {
      $0.circleColor = .pink
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.purple)) {
      $0.circleColor = .purple
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.yellow)) {
      $0.circleColor = .yellow
    }

    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.setColor(.white)) {
      $0.circleColor = .white
    }

    await self.scheduler.run()
  }
}
