import ComposableArchitecture
import XCTest

@MainActor
final class FilterReducerTests: XCTestCase {
  
  struct MainReducer: ReducerProtocol {
    struct State: Equatable { }
    
    enum Action {
      case limitedAction
      case notLimitedAction
      case anotherAction
      case another2Action
      case alert
    }
    
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      switch action {
      case .limitedAction:
        return Effect(value: .notLimitedAction)
      case .notLimitedAction:
        return Effect(value: .anotherAction)
      case .anotherAction:
        return .none
      case .another2Action:
        return Effect(value: .anotherAction)
      case .alert:
        return .none
      }
    }
  }
  
  struct FilterReducer: ReducerProtocol {
    typealias State = MainReducer.State
    typealias Action = MainReducer.Action
    
    func reduce(into state: inout FilterReducerTests.MainReducer.State, action: FilterReducerTests.MainReducer.Action) -> EffectTask<FilterReducerTests.MainReducer.Action> {
      switch action {
      case .limitedAction:
        return Effect(value: .alert)
      default: return .none
      }
    }
  }

  struct BlockReducer: ReducerProtocol {
    typealias State = MainReducer.State
    typealias Action = MainReducer.Action
    
    func reduce(into state: inout FilterReducerTests.MainReducer.State, action: FilterReducerTests.MainReducer.Action) -> EffectTask<FilterReducerTests.MainReducer.Action> {
      switch action {
      case .notLimitedAction:
        return Effect(value: .alert)
      case .another2Action:
        return .none
      default: return .passthrough
      }
    }
  }

  func testFilterAction() async {
    let store = TestStore(initialState: MainReducer.State(), reducer: MainReducer().filter(\.self, action: /.self, then: { FilterReducer() }))
    _ = await store.send(.limitedAction)
    await store.receive(.alert)
    
    _ = await store.send(.notLimitedAction)
    await store.receive(.anotherAction)
    
    _ = await store.send(.alert)
    _ = await store.send(.anotherAction)
  }
  
  func testBlockAction() async {
    let store = TestStore(initialState: MainReducer.State(), reducer: MainReducer().filter(behaviour: .block, \.self, action: /.self, then: { BlockReducer() }))
    _ = await store.send(.notLimitedAction)
    await store.receive(.alert)
    
    _ = await store.send(.limitedAction)
    await store.receive(.notLimitedAction)
    await store.receive(.alert)

    _ = await store.send(.anotherAction)
    _ = await store.send(.alert)
    _ = await store.send(.another2Action)
  }
}
