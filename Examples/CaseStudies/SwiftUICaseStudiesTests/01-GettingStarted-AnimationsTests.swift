import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class AnimationTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testRainbow() {
    let store = TestStore(
      initialState: AnimationsState(),
      reducer: animationsReducer,
      environment: AnimationsEnvironment(
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.assert(
      .send(.rainbowButtonTapped),

      .receive(.setColor(.red)) {
        $0.circleColor = .red
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.blue)) {
        $0.circleColor = .blue
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.green)) {
        $0.circleColor = .green
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.orange)) {
        $0.circleColor = .orange
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.pink)) {
        $0.circleColor = .pink
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.purple)) {
        $0.circleColor = .purple
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.yellow)) {
        $0.circleColor = .yellow
      },

      .do { self.scheduler.advance(by: .seconds(1)) },
      .receive(.setColor(.white)) {
        $0.circleColor = .white
      },

      .do { self.scheduler.run() }
    )
  }
}
