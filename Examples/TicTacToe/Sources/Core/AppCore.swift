import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public struct AppState: Equatable {
  public var login: LoginState? = LoginState()
  public var newGame: NewGameState?

  public init() {}
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

public let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  loginReducer.optional().pullback(
    state: \.login,
    action: /AppAction.login,
    environment: {
      LoginEnvironment(
        authenticationClient: $0.authenticationClient,
        mainQueue: $0.mainQueue
      )
    }
  ),
  newGameReducer.optional().pullback(
    state: \.newGame,
    action: /AppAction.newGame,
    environment: { _ in NewGameEnvironment() }
  ),
  Reducer { state, action, _ in
    switch action {
    case let .login(.twoFactor(.twoFactorResponse(.success(response)))),
      let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
      state.newGame = NewGameState()
      state.login = nil
      return .none

    case .login:
      return .none

    case .newGame(.logoutButtonTapped):
      state.newGame = nil
      state.login = LoginState()
      return .none

    case .newGame:
      return .none
    }
  }
)
