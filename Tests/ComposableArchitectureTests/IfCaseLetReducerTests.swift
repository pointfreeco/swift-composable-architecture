import ComposableArchitecture
import XCTest

@MainActor
final class IfCaseLetReducerTests: BaseTCATestCase {
  func testChildAction() async {
    struct SomeError: Error, Equatable {}

    let store = TestStore(
      initialState: Result.success(0),
      reducer: Reduce<Result<Int, SomeError>, Result<Int, SomeError>> { state, action in
        .none
      }
      .ifCaseLet(/Result.success, action: /Result.success) {
        Reduce { state, action in
          state = action
          return state < 0 ? .run { await $0(0) } : .none
        }
      }
    )

    await store.send(.success(1)) {
      $0 = .success(1)
    }
    await store.send(.failure(SomeError()))
    await store.send(.success(-1)) {
      $0 = .success(-1)
    }
    await store.receive(.success(0)) {
      $0 = .success(0)
    }
  }

  #if DEBUG
    func testNilChild() async {
      struct SomeError: Error, Equatable {}

      let store = TestStore(
        initialState: Result.failure(SomeError()),
        reducer: EmptyReducer<Result<Int, SomeError>, Result<Int, SomeError>>()
          .ifCaseLet(/Result.success, action: /Result.success) {}
      )

      XCTExpectFailure {
        $0.compactDescription == """
          An "ifCaseLet" at "\(#fileID):\(#line - 5)" received a child action when child state was \
          set to a different case. …

            Action:
              Result.success(1)
            State:
              Result.failure(IfCaseLetReducerTests.SomeError())

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer set "Result" to a different case before this reducer ran. This \
          reducer must run before any other reducer sets child state to a different case. This \
          ensures that child reducers can handle their actions while their state is still available.

          • An in-flight effect emitted this action when child state was unavailable. While it may \
          be perfectly reasonable to ignore this action, consider canceling the associated effect \
          before child state changes to another case, especially if it is a long-living effect.

          • This action was sent to the store while state was another case. Make sure that actions \
          for this reducer can only be sent from a view store when state is set to the appropriate \
          case. In SwiftUI applications, use "SwitchStore".
          """
      }

      await store.send(.success(1))
    }
  #endif

  #if swift(>=5.7)
    func testEffectCancellation_Siblings() async {
      if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
        struct Child: ReducerProtocol {
          struct State: Equatable {
            var count = 0
          }
          enum Action: Equatable {
            case timerButtonTapped
            case timerTick
          }
          @Dependency(\.continuousClock) var clock
          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            switch action {
            case .timerButtonTapped:
              return .run { send in
                for await _ in self.clock.timer(interval: .seconds(1)) {
                  await send(.timerTick)
                }
              }
            case .timerTick:
              state.count += 1
              return .none
            }
          }
        }
        struct Parent: ReducerProtocol {
          enum State: Equatable {
            case child1(Child.State)
            case child2(Child.State)
          }
          enum Action: Equatable {
            case child1(Child.Action)
            case child1ButtonTapped
            case child2(Child.Action)
            case child2ButtonTapped
          }
          var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
              switch action {
              case .child1:
                return .none
              case .child1ButtonTapped:
                state = .child1(Child.State())
                return .none
              case .child2:
                return .none
              case .child2ButtonTapped:
                state = .child2(Child.State())
                return .none
              }
            }
            .ifCaseLet(/State.child1, action: /Action.child1) {
              Child()
            }
            .ifCaseLet(/State.child2, action: /Action.child2) {
              Child()
            }
          }
        }
        await _withMainSerialExecutor {
          let clock = TestClock()
          let store = TestStore(
            initialState: Parent.State.child1(Child.State()),
            reducer: Parent()
          ) {
            $0.continuousClock = clock
          }
          await store.send(.child1(.timerButtonTapped))
          await clock.advance(by: .seconds(1))
          await store.receive(.child1(.timerTick)) {
            try (/Parent.State.child1).modify(&$0) {
              $0.count = 1
            }
          }
          await store.send(.child2ButtonTapped) {
            $0 = .child2(Child.State())
          }
        }
      }
    }
  #endif
}
