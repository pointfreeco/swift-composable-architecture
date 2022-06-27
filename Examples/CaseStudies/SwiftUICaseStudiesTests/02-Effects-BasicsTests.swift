@testable import CombineSchedulers
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

import SwiftUI

@MainActor
class EffectsBasicsTests: XCTestCase {
  func testCountUpAndDown() {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .failing
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }

  func testDecrement() async {
    let scheduler = DispatchQueue.test

    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    await scheduler.advance(by: .seconds(1))
    await store.receive(.delayedDecrementButtonTapped) {
      $0.count = 0
    }
  }

  func testDecrementCancellation() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .failing
      )
    )

    store.send(.decrementButtonTapped) {
      $0.count = -1
    }
    store.send(.incrementButtonTapped) {
      $0.count = 0
    }
  }


  func testNumberFact_HappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .failing
      )
    )

    store.environment.fact.fetchAsync = { n in "\(n) is a good number Brent" }

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

  func testNumberFact_UnhappyPath() async {
    let store = TestStore(
      initialState: EffectsBasicsState(),
      reducer: effectsBasicsReducer,
      environment: EffectsBasicsEnvironment(
        fact: .failing,
        mainQueue: .failing
      )
    ) 

    struct SomeOtherError: Error, Equatable {}

    store.environment.fact.fetchAsync = { _ in throw SomeOtherError() }

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.numberFactButtonTapped) {
      $0.isNumberFactRequestInFlight = true
    }
    await store.receive(.numberFactResponse(.failure(SomeOtherError()))) {
      $0.isNumberFactRequestInFlight = false
    }
  }
}


extension TestScheduler {
  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    let finalDate = self.now.advanced(by: stride)

    while self.now < finalDate {
      for _ in 1...10 { await Task.yield() }
      self.scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }

      guard
        let nextDate = self.scheduled.first?.date,
        finalDate >= nextDate
      else {
        self.now = finalDate
        return
      }

      self.now = nextDate

      while let (_, date, action) = self.scheduled.first, date == nextDate {
        self.scheduled.removeFirst()
        action()
      }
    }
  }
}
