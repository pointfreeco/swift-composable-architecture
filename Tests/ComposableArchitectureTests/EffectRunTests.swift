import Combine
import XCTest

@testable import ComposableArchitecture

@MainActor
final class EffectRunTests: XCTestCase {
  func testRunCancellation() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, response }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .run { send in
          withUnsafeCurrentTask { $0?.cancel() }
          await send(.response)
        }
      case .response:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    await store.send(.tapped).finish()
  }

  func testRunCancellation2() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .run { send in
          try await withThrowingTaskGroup(of: Void.self) { group in
            _ = group.addTaskUnlessCancelled {
              withUnsafeCurrentTask { $0?.cancel() }
              await send(.responseA)
            }
            _ = group.addTaskUnlessCancelled {
              await send(.responseB)
            }
            try await group.waitForAll()
          }
        }
      case .responseA, .responseB:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    store.send(.tapped)
    await store.receive(.responseB)
    await store.finish()
  }

  func testRunCancellationCatch() async {
    struct State: Equatable {}
    enum Action: Equatable { case tapped, responseA, responseB }
    let reducer = Reducer<State, Action, Void> { state, action, _ in
      switch action {
      case .tapped:
        return .run { send in
          withUnsafeCurrentTask { $0?.cancel() }
          try Task.checkCancellation()
          await send(.responseA)
        } catch: { _, send in
          await send(.responseB)
        }
      case .responseA, .responseB:
        return .none
      }
    }
    let store = TestStore(initialState: State(), reducer: reducer, environment: ())
    await store.send(.tapped).finish()
  }
}
