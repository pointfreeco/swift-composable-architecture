#if swift(>=5.9)
  import Combine
  @_spi(Internals) import ComposableArchitecture
  import CustomDump
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

    @Reducer
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    fileprivate struct Feature_testCombine_EffectsAreMerged {
      typealias State = Int
      enum Action { case increment }
      @Dependency(\.continuousClock) var clock
      let delay: Duration
      let setValue: @Sendable () async -> Void
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          state += 1
          return .run { _ in
            try await self.clock.sleep(for: self.delay)
            await self.setValue()
          }
        }
      }
    }
    func testCombine_EffectsAreMerged() async throws {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        var fastValue: Int? = nil
        var slowValue: Int? = nil
        let clock = TestClock()

        let store = TestStore(initialState: 0) {
          Feature_testCombine_EffectsAreMerged(
            delay: .seconds(1), setValue: { @MainActor in fastValue = 42 })
          Feature_testCombine_EffectsAreMerged(
            delay: .seconds(2), setValue: { @MainActor in slowValue = 1729 })
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

    @Reducer
    fileprivate struct Feature_testCombine {
      typealias State = Int
      enum Action { case increment }
      let effect: @Sendable () async -> Void
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          state += 1
          return .run { _ in
            await self.effect()
          }
        }
      }
    }
    func testCombine() async {
      var first = false
      var second = false

      let store = TestStore(initialState: 0) {
        Feature_testCombine(effect: { @MainActor in first = true })
        Feature_testCombine(effect: { @MainActor in second = true })
      }

      await store
        .send(.increment) { $0 = 2 }
        .finish()

      XCTAssertTrue(first)
      XCTAssertTrue(second)
    }

    func testDefaultSignpost() async {
      let reducer = EmptyReducer<Int, Void>().signpost(log: .default)
      var n = 0
      for await _ in reducer.reduce(into: &n, action: ()).actions {}
    }

    func testDisabledSignpost() async {
      let reducer = EmptyReducer<Int, Void>().signpost(log: .disabled)
      var n = 0
      for await _ in reducer.reduce(into: &n, action: ()).actions {}
    }
  }
#endif
