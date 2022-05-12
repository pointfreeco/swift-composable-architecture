import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public enum AppState: Equatable {
  case login(Login.State)
  case newGame(NewGameState)

  public init() { self = .login(.init()) }
}

public enum AppAction: Equatable {
  case login(Login.Action)
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
  Reducer(Login()).pullback(
    state: /AppState.login,
    action: /AppAction.login,
    environment: { _ in }
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
      state = .newGame(.init())
      return .none

    case .login:
      return .none

    case .newGame(.logoutButtonTapped):
      state = .login(.init())
      return .none

    case .newGame:
      return .none
    }
  }
)
.debug()
