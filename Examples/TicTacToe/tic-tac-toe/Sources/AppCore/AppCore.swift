import ComposableArchitecture
import LoginCore
import NewGameCore

@Reducer
public enum TicTacToe {
  case login(Login)
  case newGame(NewGame)

  public static var body: some ReducerOf<Self> {
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
extension TicTacToe.State: Equatable {}
