import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore

@Reducer
public struct TicTacToe {
  public enum State: Equatable {
    case login(Login.State)
    case newGame(NewGame.State)

    public init() { self = .login(Login.State()) }
  }

  public enum Action {
    case login(Login.Action)
    case newGame(NewGame.Action)
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .login(.twoFactor(.presented(.twoFactorResponse(.success)))):
        state = .newGame(NewGame.State())
        return .none

      case let .login(.loginResponse(.success(response))) where !response.twoFactorRequired:
        state = .newGame(NewGame.State())
        return .none

      case .login:
        return .none

      case .newGame(.logoutButtonTapped):
        state = .login(Login.State())
        return .none

      case .newGame:
        return .none
      }
    }
    .ifCaseLet(\.login, action: \.login) {
      Login()
    }
    .ifCaseLet(\.newGame, action: \.newGame) {
      NewGame()
    }
  }
}
