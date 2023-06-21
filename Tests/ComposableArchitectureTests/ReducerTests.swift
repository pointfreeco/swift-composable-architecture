import Combine
import ComposableArchitecture
import CustomDump
@_spi(Concurrency) import Dependencies
import XCTest
import os.signpost

@MainActor
final class ReducerTests: BaseTCATestCase {
  var cancellables: Set<AnyCancellable> = []

  func testCallableAsFunction() {
    let reducer = Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }

    var state = 0
    _ = reducer.reduce(into: &state, action: ())
    XCTAssertEqual(state, 1)
  }

  #if (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testCombine_EffectsAreMerged() async throws {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        try await withMainSerialExecutor {
          enum Action: Equatable {
            case increment
          }

          struct Delayed: ReducerProtocol {
            typealias State = Int

            @Dependency(\.continuousClock) var clock

            let delay: Duration
            let setValue: @Sendable () async -> Void

            func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
              state += 1
              return .fireAndForget {
                try await self.clock.sleep(for: self.delay)
                await self.setValue()
              }
            }
          }

          var fastValue: Int? = nil
          var slowValue: Int? = nil

          let clock = TestClock()

          let store = TestStore(initialState: 0) {
            Delayed(delay: .seconds(1), setValue: { @MainActor in fastValue = 42 })
            Delayed(delay: .seconds(2), setValue: { @MainActor in slowValue = 1729 })
          } withDependencies: {
            $0.continuousClock = clock
          }

          await store.send(.increment) {
            $0 = 2
          }
          // Waiting a second causes the fast effect to fire.
          await clock.advance(by: .seconds(1))
          try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
          XCTAssertEqual(fastValue, 42)
          XCTAssertEqual(slowValue, nil)
          // Waiting one more second causes the slow effect to fire. This proves that the effects
          // are merged together, as opposed to concatenated.
          await clock.advance(by: .seconds(1))
          await store.finish()
          XCTAssertEqual(fastValue, 42)
          XCTAssertEqual(slowValue, 1729)
        }
      }
    }
  #endif

  func testCombine() async {
    enum Action: Equatable {
      case increment
    }

    struct One: ReducerProtocol {
      typealias State = Int
      let effect: @Sendable () async -> Void
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        state += 1
        return .fireAndForget {
          await self.effect()
        }
      }
    }

    var first = false
    var second = false

    let store = TestStore(initialState: 0) {
      One(effect: { @MainActor in first = true })
      One(effect: { @MainActor in second = true })
    }

    await store
      .send(.increment) { $0 = 2 }
      .finish()

    XCTAssertTrue(first)
    XCTAssertTrue(second)
  }

  func testDefaultSignpost() {
    let reducer = EmptyReducer<Int, Void>().signpost(log: .default)
    var n = 0
    let effect = reducer.reduce(into: &n, action: ())
    let expectation = self.expectation(description: "effect")
    effect
      .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
      .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.1)
  }

  func testDisabledSignpost() {
    let reducer = EmptyReducer<Int, Void>().signpost(log: .disabled)
    var n = 0
    let effect = reducer.reduce(into: &n, action: ())
    let expectation = self.expectation(description: "effect")
    effect
      .sink(receiveCompletion: { _ in expectation.fulfill() }, receiveValue: { _ in })
      .store(in: &self.cancellables)
    self.wait(for: [expectation], timeout: 0.1)
  }
}
