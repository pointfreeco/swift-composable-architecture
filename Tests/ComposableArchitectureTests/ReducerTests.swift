import Combine
import ComposableArchitecture
import CustomDump
import XCTest
import os.signpost

public extension ReducerProtocol {
    @inlinable
    func onChange<ChildState: Equatable>(
        of toLocalState: @escaping (State) -> ChildState,
        perform additionalEffects: @escaping (ChildState, inout State, Action) -> EffectTask<
            Action
        >
    ) -> some ReducerProtocol<State, Action> {
        self.onChange(of: toLocalState) { additionalEffects($1, &$2, $3) }
    }

    @inlinable
    func onChange<ChildState: Equatable>(
        of toLocalState: @escaping (State) -> ChildState,
        perform additionalEffects: @escaping (ChildState, ChildState, inout State, Action) -> EffectTask<
            Action
        >
    ) -> some ReducerProtocol<State, Action> {
        ChangeReducer(base: self, toLocalState: toLocalState, perform: additionalEffects)
    }
}

@usableFromInline
struct ChangeReducer<Base: ReducerProtocol, ChildState: Equatable>: ReducerProtocol {
    @usableFromInline let base: Base

    @usableFromInline let toLocalState: (Base.State) -> ChildState

    @usableFromInline let perform:
        (ChildState, ChildState, inout Base.State, Base.Action) -> EffectTask<
            Base.Action
        >

    @usableFromInline
    init(
        base: Base,
        toLocalState: @escaping (Base.State) -> ChildState,
        perform: @escaping (ChildState, ChildState, inout Base.State, Base.Action) -> EffectTask<
            Base.Action
        >
    ) {
        self.base = base
        self.toLocalState = toLocalState
        self.perform = perform
    }

    @inlinable
    public func reduce(into state: inout Base.State, action: Base.Action) -> EffectTask<
        Base.Action
    > {
        let previousLocalState = self.toLocalState(state)
        let effects = self.base.reduce(into: &state, action: action)
        let localState = self.toLocalState(state)

        return previousLocalState != localState
            ? .merge(effects, self.perform(previousLocalState, localState, &state, action))
            : effects
    }
}


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

  #if swift(>=5.7) && (canImport(RegexBuilder) || !os(macOS) && !targetEnvironment(macCatalyst))
    func testCombine_EffectsAreMerged() async throws {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        try await _withMainSerialExecutor {
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

          let store = TestStore(
            initialState: 0,
            reducer: CombineReducers {
              Delayed(delay: .seconds(1), setValue: { @MainActor in fastValue = 42 })
              Delayed(delay: .seconds(2), setValue: { @MainActor in slowValue = 1729 })
            }
          ) {
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
    struct State: Equatable {
      var counter: Int
    }

    enum Action: Equatable {
      case increment
    }

    struct One: ReducerProtocol {
      let effect: @Sendable () async -> Void
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        state.counter += 1
        return .fireAndForget {
          await self.effect()
        }
      }
    }

    struct Two: ReducerProtocol {
      let effect: @Sendable () async -> Void
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        state.counter += 1
        return .fireAndForget {
          await self.effect()
        }
      }
    }

    var first = false
    var second = false

    let _store = Store(
      initialState: State(counter: 0),
      reducer: CombineReducers {
        One(effect: { @MainActor in first = true })
        Two(effect: { @MainActor in second = true })
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }.onChange(of: \.counter) { _, _, _ in
          .send(.increment)
      }
    )

    let store = TestStore(
      initialState: State(counter: 0),
      reducer: CombineReducers {
        One(effect: { @MainActor in first = true })
        One(effect: { @MainActor in second = true })
      }
    )

    await store
      .send(.increment) { $0.counter = 2 }
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
