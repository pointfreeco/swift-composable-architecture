import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class AnimationTests: XCTestCase {
  func testRainbow() async {
    let store = TestStore(
      initialState: Animations.State(),
      reducer: Animations()
    )

    let mainQueue = DispatchQueue.test
    store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()

    await store.send(.rainbowButtonTapped)
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
    await store.receive(.setColor(.black)) {
      $0.circleColor = .black
    }

    await mainQueue.run()
  }

  func testReset() async {
    let store = TestStore(
      initialState: Animations.State(),
      reducer: Animations()
    )

    let mainQueue = DispatchQueue.test
    store.dependencies.mainQueue = mainQueue.eraseToAnyScheduler()

    await store.send(.rainbowButtonTapped)
    await store.receive(.setColor(.red)) {
      $0.circleColor = .red
    }

    await mainQueue.advance(by: .seconds(1))
    await store.receive(.setColor(.blue)) {
      $0.circleColor = .blue
    }

    await store.send(.resetButtonTapped) {
      $0.alert = AlertState(
        title: TextState("Reset state?"),
        primaryButton: .destructive(
          TextState("Reset"),
          action: .send(.resetConfirmationButtonTapped, animation: .default)
        ),
        secondaryButton: .cancel(TextState("Cancel"))
      )
    }

    await store.send(.resetConfirmationButtonTapped) {
      $0 = Animations.State()
    }
  }
}
