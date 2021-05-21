import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public enum AppState: Equatable {
  case login(LoginState)
  case newGame(NewGameState)

  public init() {
    self = .login(.init())
  }
}

public enum AppAction: Equatable {
  case login(LoginAction)
  case newGame(NewGameAction)
}

public struct AppEnvironment {
  public var authenticationClient: AuthenticationClient
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    authenticationClient: AuthenticationClient,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.authenticationClient = authenticationClient
    self.mainQueue = mainQueue
  }
}

extension Reducer {
  public func pullback<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: CasePath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }

      guard var localState = toLocalState.extract(from: globalState) else { return .none }
      defer { globalState = toLocalState.embed(localState) }

      let effects = self.run(
        &localState,
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map(toLocalAction.embed)

      return effects
    }
  }
}

public let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  loginReducer.pullback(
    state: /AppState.login,
    action: /AppAction.login,
    environment: {
      LoginEnvironment(
        authenticationClient: $0.authenticationClient,
        mainQueue: $0.mainQueue
      )
    }
  ),
  newGameReducer.pullback(
    state: /AppState.newGame,
    action: /AppAction.newGame,
    environment: { _ in NewGameEnvironment() }
  ),
  Reducer { state, action, environment in
    switch action {
    case let .login(.twoFactor(.twoFactorResponse(.success(response)))),
      let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
      state = .newGame(NewGameState())
      return .none

    case .newGame(.logoutButtonTapped):
      state = .login(LoginState())
      return .none

    case .login, .newGame:
      return .none
    }
  }
)
