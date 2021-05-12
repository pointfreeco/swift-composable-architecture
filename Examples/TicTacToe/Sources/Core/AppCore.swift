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

public let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
//  loginReducer.optional().pullback(
//    state: \.login,
//    action: /AppAction.login,
//    environment: {
//      LoginEnvironment(
//        authenticationClient: $0.authenticationClient,
//        mainQueue: $0.mainQueue
//      )
//    }
//  ),
//  newGameReducer.optional().pullback(
//    state: \.newGame,
//    action: /AppAction.newGame,
//    environment: { _ in NewGameEnvironment() }
//  ),
  Reducer { state, action, environment in
    switch action {
    case let .login(.twoFactor(.twoFactorResponse(.success(response)))),
      let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
      state = .newGame(NewGameState())
      return .none

    case let .login(loginAction):
      guard case var .login(loginState) = state else { return .none }
      defer { state = .login(loginState) }
      return loginReducer
        .run(
          &loginState, loginAction,
          LoginEnvironment(
            authenticationClient: environment.authenticationClient,
            mainQueue: environment.mainQueue
          )
        )
        .map(AppAction.login)

    case .newGame(.logoutButtonTapped):
      state = .login(LoginState())
      return .none

    case let .newGame(newGameAction):
      guard case var .newGame(newGameState) = state else { return .none }
      defer { state = .newGame(newGameState) }
      return newGameReducer
        .run(
          &newGameState,
          newGameAction,
          NewGameEnvironment()
        )
        .map(AppAction.newGame)
    }
  }
)
