import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

struct Environment {
  let sleep: (UInt64) async -> Void

  static let test = Environment(
    sleep: {
      await Task.sleep($0 / 1_000_000)
    }
  )
}

class EffectsBasicsTests: XCTestCase {
  func testCountDown() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
    await Task.sleep(1_000_000_000)
    store.receive(.incrementButtonTapped) {
      $0.count = 1
    }
  }

  @MainActor
  func testNumberFact() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .init(
          asyncFetch: { "\($0) is a good number Brent" },
          fetch: { n in Effect(value: "\(n) is a good number Brent") }
        ),
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await Task.sleep(100_000)
    store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }

  func testFoo() async {
    let t: () = await withCheckedContinuation { continuation in

    }
  }
}
