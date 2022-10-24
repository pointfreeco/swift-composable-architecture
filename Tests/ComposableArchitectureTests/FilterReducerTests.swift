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
    let store = TestStore(initialState: MainReducer.State(), reducer: MainReducer().filter(\.self, action: /.self, then: { FilterReducer() }, behaviour: .block))
    _ = await store.send(.limitedAction)
    await store.receive(.alert)
    
    _ = await store.send(.notLimitedAction)
    _ = await store.send(.alert)
    _ = await store.send(.anotherAction)
  }
}
