import Clocks
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class AnimationTests: XCTestCase {
  func testRainbow() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: Animations.State(),
      reducer: Animations()
    ) {
      $0.continuousClock = clock
    }

    await store.send(.rainbowButtonTapped)
    await store.receive(.setColor(.red)) {
      $0.circleColor = .red
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.blue)) {
      $0.circleColor = .blue
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.green)) {
      $0.circleColor = .green
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.orange)) {
      $0.circleColor = .orange
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.pink)) {
      $0.circleColor = .pink
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.purple)) {
      $0.circleColor = .purple
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.yellow)) {
      $0.circleColor = .yellow
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.black)) {
      $0.circleColor = .black
    }

    await clock.run()
  }

  func testReset() async {
    let clock = TestClock()

    let store = TestStore(
      initialState: Animations.State(),
      reducer: Animations()
    ) {
      $0.continuousClock = clock
    }

    await store.send(.rainbowButtonTapped)
    await store.receive(.setColor(.red)) {
      $0.circleColor = .red
    }

    await clock.advance(by: .seconds(1))
    await store.receive(.setColor(.blue)) {
      $0.circleColor = .blue
    }

    await store.send(.resetButtonTapped) {
      $0.alert = AlertState {
        TextState("Reset state?")
      } actions: {
        ButtonState(
          role: .destructive,
          action: .send(.resetConfirmationButtonTapped, animation: .default)
        ) {
          TextState("Reset")
        }
        ButtonState(role: .cancel) {
          TextState("Cancel")
        }
      }
    }

    await store.send(.resetConfirmationButtonTapped) {
      $0 = Animations.State()
    }

    await store.finish()
  }
}
