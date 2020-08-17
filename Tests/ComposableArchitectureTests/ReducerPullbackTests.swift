import Combine
import CombineSchedulers
import ComposableArchitecture
import XCTest
import os.signpost

final class ReducerPullbackTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testVoidPullbacks() {
    class Counter {
      var count: Int = 0
      func inc() {
        count += 1
      }
    }
    
    struct CounterClient {
      var inc: () -> Effect<Never, Never>
    }
    
    struct GlobalState: Equatable {
      var local: LocalState
    }
    
    enum GlobalAction: Equatable {
      case local(LocalAction)
      
      var local: LocalAction? {
        if case let .local(action) = self { return action }
        return nil
      }
    }
    
    struct GlobalEnvironment {
      var counterClient: CounterClient
    }
    
    struct LocalState: Equatable {
      var flag: Bool
    }
    
    enum LocalAction: Equatable {
      case inc
      case makeTrue
    }
    
    let localIncActionReducer = Reducer<Void, LocalAction, GlobalEnvironment>.combine(
      Reducer { state, action, environment in
        switch action {
        case .inc:
          state = () // no crash check
          return environment.counterClient.inc()
            .fireAndForget()
          
        default:
          return .none
        }
      }
    )
    
    let localMakeTrueActionReducer = Reducer<LocalState, LocalAction, Void>.combine(
      Reducer { state, action, _ in
        switch action {
        case .makeTrue:
          state.flag = true
          return .none
          
        default:
          return .none
        }
      }
    )
    
    let globalReducer = Reducer<GlobalState, GlobalAction, GlobalEnvironment>.combine(
      // Test reducer with void state
      localIncActionReducer.pullback(
        action: /GlobalAction.local,
        environment: { $0 }
      ),
      
      // Test reducer with void environment
      localMakeTrueActionReducer.pullback(
        state: \.local,
        action: /GlobalAction.local
      ),
      
      // Global reducer
      Reducer { state, action, environment in
        return .none
      }
    )
    
    let counter = Counter()
    let counterClient = CounterClient {
      .fireAndForget { counter.inc() }
    }
    
    let initialState = GlobalState(local: .init(flag: false))
    let store = TestStore(
      initialState: initialState,
      reducer: globalReducer,
      environment: GlobalEnvironment(counterClient: counterClient)
    )
    
    store.assert(
      .send(.local(.inc)) { state in
        XCTAssertEqual(counter.count, 1)
        state = initialState
      },
      .send(.local(.inc)) { state in
        XCTAssertEqual(counter.count, 2)
        state = initialState
      },
      .send(.local(.makeTrue)) { state in
        XCTAssertEqual(counter.count, 2)
        state.local.flag = true
      }
    )
  }

}
