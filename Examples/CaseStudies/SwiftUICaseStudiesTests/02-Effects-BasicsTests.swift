import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

extension AsyncFactClient {
  static let failing = Self(
    fetch: { _ in
      XCTFail("AsyncFactClient.fetch is unimplemented")
      return "AsyncFactClient.fetch is unimplemented"
    }
  )
}

extension TestScheduler {
  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    await Task.yield()
    _ = { self.advance(by: stride) }()
  }

  @MainActor
  public func run() async {
    await Task.yield()
    _ = { self.run() }()
  }
}

class EffectsBasicsTests: XCTestCase {
  @MainActor
  func testCountDown() async {
    let scheduler = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
    await scheduler.advance(by: 1)
    await store.receive(.incrementButtonTapped) {
      $0.count = 1
    }
  }

  @MainActor
  func testNumberFact() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .init(fetch: { n in "\(n) is a good number Brent" }),
        mainQueue: .immediate
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
      $0.isNumberFactRequestInFlight = false
      $0.numberFact = "1 is a good number Brent"
    }
  }
}
