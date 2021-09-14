import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

public enum AppState: Equatable {
  case login(LoginState)
  case newGame(NewGameState)

  public init() { self = .login(.init()) }
}

public enum AppAction: Equatable {
  case login(LoginAction)
  case newGame(NewGameAction)
}

public struct AppReducer: _Reducer {
  public init() {}

  public static let main = LoginReducer.main
    .pullback(state: /AppState.login, action: /AppAction.login)
    .combined(
      with: NewGameReducer.main
        .pullback(state: /AppState.newGame, action: /AppAction.newGame)
    )
    .combined(with: Self())
    .debug()

  public func reduce(into state: inout AppState, action: AppAction) -> Effect<AppAction, Never> {
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
}
