import ComposableArchitecture

// MARK: - States
struct BaseState: Equatable {
  var string: String = ""
  var integer: Int = 0
}

struct BindableBaseState: Equatable {
  @BindableState var string: String = ""
  @BindableState var integer: Int = 0
}

struct RootState: Equatable {
  var base: BaseState = .init()
}

// MARK: - Actions
enum BaseAction {
  case reset
  case setString(String)
  case setInteger(Int)
  case indirectReset
  case indirectResetViaEnvironment
}

enum BindableBaseAction: BindableAction {
  case binding(BindingAction<BindableBaseState>)
  case reset
  case setString(String)
  case setInteger(Int)
  case indirectReset
  case indirectResetViaEnvironment
}

enum RootAction {
  case base(BaseAction)
}

// MARK: - Environments
struct BaseEnvironment {
  var effect: Effect<BaseAction, Never> {
    Effect(value: .reset)
  }
}

// MARK: - Reducers
let baseReducer: Reducer<BaseState, BaseAction, BaseEnvironment> = .init {
  state, action, environment in
  switch action {
  case .reset:
    state.integer = 0
    state.string = ""
    return .none
  case let .setString(string):
    state.string = string
    return .none
  case let .setInteger(integer):
    state.integer = integer
    return .none
  case .indirectReset:
    return Effect(value: .reset)
  case .indirectResetViaEnvironment:
    return environment.effect
  }
}

let rootReducer = baseReducer.pullback(
  state: \RootState.base,
  action: /RootAction.base,
  environment: { $0 }
)
