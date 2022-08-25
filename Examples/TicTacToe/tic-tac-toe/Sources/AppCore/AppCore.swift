import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public enum AppState: Equatable {
  case login(LoginState)
  case newGame(NewGameState)

  public init() { self = .login(LoginState()) }
}

public enum AppAction: Equatable {
  case login(LoginAction)
  case newGame(NewGameAction)
}

public struct AppEnvironment {
  public var authenticationClient: AuthenticationClient

  public init(
    authenticationClient: AuthenticationClient
  ) {
    self.authenticationClient = authenticationClient
  }
}

public let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  loginReducer.pullback(
    state: /AppState.login,
    action: /AppAction.login,
    environment: {
      LoginEnvironment(
        authenticationClient: $0.authenticationClient
      )
    }
  ),
  newGameReducer.pullback(
    state: /AppState.newGame,
    action: /AppAction.newGame,
    environment: { _ in NewGameEnvironment() }
  ),
  Reducer { state, action, _ in
    switch action {
    case let .login(.twoFactor(.twoFactorResponse(.success(response)))),
      let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
      state = .newGame(NewGameState())
      return .none

    case .login:
      return .none

    case .newGame(.logoutButtonTapped):
      state = .login(LoginState())
      return .none

    case .newGame:
      return .none
    }
  }
)
