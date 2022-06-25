import Benchmark
import ComposableArchitecture

let reducerVsProtocol = BenchmarkSuite(name: "Reducer vs Protocol") { suite in
  let count = 1

  suite.benchmark("Reducer") {
    var state = RootState()
    for _ in 1...count {
      _ = rootReducer.run(&state, .stateA1(.stateB2(.doSomething)), ())
    }
    precondition(state.stateA1.stateB2.int == count)
  }

  suite.benchmark("Protocol") {
    var state = RootState()
    let reducer = Root()
    for _ in 1...count {
      _ = reducer.reduce(into: &state, action: .stateA1(.stateB2(.doSomething)))
    }
    precondition(state.stateA1.stateB2.int == count)
  }
}

private struct RootState {
  var int = 0
  var string = ""
  var bool = false
  var stateA1 = ScreenAState()
  var stateA2 = ScreenAState()
  var stateA3 = ScreenAState()
}
private enum RootAction {
  case doSomething
  case stateA1(ScreenAAction)
  case stateA2(ScreenAAction)
  case stateA3(ScreenAAction)
}
private let rootReducer = Reducer<RootState, RootAction, Void>.combine(
  .init { state, action, _ in
    switch action {
    case .doSomething:
      state.int += 1
      state.string += "\(state.int),"
      state.bool.toggle()
    default:
      return .none
    }
    return .none
  },
  screenAReducer
    .pullback(state: \.stateA1, action: /RootAction.stateA1, environment: { $0 }),
  screenAReducer
    .pullback(state: \.stateA2, action: /RootAction.stateA2, environment: { $0 }),
  screenAReducer
    .pullback(state: \.stateA3, action: /RootAction.stateA3, environment: { $0 })
)
private struct ScreenAState {
  var int = 0
  var string = ""
  var bool = false
  var stateB1 = ScreenBState()
  var stateB2 = ScreenBState()
  var stateB3 = ScreenBState()
}
private enum ScreenAAction {
  case doSomething
  case stateB1(ScreenBAction)
  case stateB2(ScreenBAction)
  case stateB3(ScreenBAction)
}
private let screenAReducer = Reducer<ScreenAState, ScreenAAction, Void>.combine(
  .init { state, action, _ in
    switch action {
    case .doSomething:
      state.int += 1
      state.string += "\(state.int),"
      state.bool.toggle()
    default:
      return .none
    }
    return .none
  },
  screenBReducer
    .pullback(state: \.stateB1, action: /ScreenAAction.stateB1, environment: { $0 }),
  screenBReducer
    .pullback(state: \.stateB2, action: /ScreenAAction.stateB2, environment: { $0 }),
  screenBReducer
    .pullback(state: \.stateB3, action: /ScreenAAction.stateB3, environment: { $0 })
)

private struct ScreenBState {
  var int = 0
  var string = ""
  var bool = false
  var stateC1 = ScreenCState()
  var stateC2 = ScreenCState()
  var stateC3 = ScreenCState()
}
private enum ScreenBAction {
  case doSomething
  case stateC1(ScreenCAction)
  case stateC2(ScreenCAction)
  case stateC3(ScreenCAction)
}
private let screenBReducer = Reducer<ScreenBState, ScreenBAction, Void>.combine(
  .init { state, action, _ in
    switch action {
    case .doSomething:
      state.int += 1
      state.string += "\(state.int),"
      state.bool.toggle()
    default:
      return .none
    }
    return .none
  },
  screenCReducer
    .pullback(state: \.stateC1, action: /ScreenBAction.stateC1, environment: { $0 }),
  screenCReducer
    .pullback(state: \.stateC2, action: /ScreenBAction.stateC2, environment: { $0 }),
  screenCReducer
    .pullback(state: \.stateC3, action: /ScreenBAction.stateC3, environment: { $0 })
)

private struct ScreenCState {}
private enum ScreenCAction {}
private let screenCReducer = Reducer<ScreenCState, ScreenCAction, Void> { state, action, _ in
  .none
}

private struct Root: ReducerProtocol {
  typealias State = RootState
  typealias Action = RootAction
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .doSomething:
        state.int += 1
        state.string += "\(state.int),"
        state.bool.toggle()
      default:
        return .none
      }
      return .none
    }
    Scope(state: \.stateA1, action: /Action.stateA1) {
      ScreenA()
    }
    Scope(state: \.stateA2, action: /Action.stateA2) {
      ScreenA()
    }
    Scope(state: \.stateA3, action: /Action.stateA3) {
      ScreenA()
    }
  }
}

private struct ScreenA: ReducerProtocol {
  typealias State = ScreenAState
  typealias Action = ScreenAAction
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .doSomething:
        state.int += 1
        state.string += "\(state.int),"
        state.bool.toggle()
      default:
        return .none
      }
      return .none
    }
    Scope(state: \.stateB1, action: /Action.stateB1) {
      ScreenB()
    }
    Scope(state: \.stateB2, action: /Action.stateB2) {
      ScreenB()
    }
    Scope(state: \.stateB3, action: /Action.stateB3) {
      ScreenB()
    }
  }
}

private struct ScreenB: ReducerProtocol {
  typealias State = ScreenBState
  typealias Action = ScreenBAction
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .doSomething:
        state.int += 1
        state.string += "\(state.int),"
        state.bool.toggle()
      default:
        return .none
      }
      return .none
    }
    Scope(state: \.stateC1, action: /Action.stateC1) {
      ScreenC()
    }
    Scope(state: \.stateC2, action: /Action.stateC2) {
      ScreenC()
    }
    Scope(state: \.stateC3, action: /Action.stateC3) {
      ScreenC()
    }
  }
}

private struct ScreenC: ReducerProtocol {
  typealias State = ScreenCState
  typealias Action = ScreenCAction
  func reduce(into state: inout ScreenCState, action: ScreenCAction) -> Effect<ScreenCAction, Never> {
    .none
  }
}
