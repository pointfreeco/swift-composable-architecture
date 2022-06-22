import AuthenticationClient
import ComposableArchitecture
import Dispatch
import LoginCore
import NewGameCore
import TwoFactorCore
import GameCore

public struct AppReducer: ReducerProtocol {
  @Dependency(\.navigationID.next) var nextID

  public init() {}

  public struct State: Hashable, NavigableState {
    public var login: Login.State
    public var path: NavigationState<DestinationState>

    public init(
      login: Login.State = Login.State(),
      path: NavigationState<DestinationState> = []
    ) {
      self.login = login
      self.path = path
    }
  }

  public enum Action: Hashable, NavigableAction {
    case login(Login.Action)
    case navigation(NavigationAction<DestinationState, DestinationAction>)
  }

  public enum DestinationState: Hashable {
    case twoFactor(TwoFactor.State)
    case newGame(NewGame.State)
    case game(Game.State)
  }

  public enum DestinationAction: Hashable {
    case twoFactor(TwoFactor.Action)
    case newGame(NewGame.Action)
    case game(Game.Action)
  }

  public var body: some ReducerProtocol<State, Action> {
    Scope(state: \State.login, action: CasePath(Action.login)) {
      Login()
    }

    Reduce { state, action in
      switch action {
      case let .login(.loginResponse(.success(response))):
        if response.twoFactorRequired {
          state.path = [
            NavigationState.Destination(
              id: self.nextID(),
              element: .twoFactor(TwoFactor.State(token: response.token))
            )
          ]
        } else {
          state.path = [.init(id: self.nextID(), element: .newGame(NewGame.State()))]
        }
        return .none

      case .login:
        return .none

      case .navigation(.element(id: _, .twoFactor(.twoFactorResponse(.success)))):
        state.path = [.init(id: self.nextID(), element: .newGame(NewGame.State()))]
        return .none

      case let .navigation(.element(id: id, .newGame(.letsPlayButtonTapped))):
        let newGameState = CasePath(DestinationState.newGame).extract(from: state.path[id: id]!)!
        state.path.append(
          .init(
            id: self.nextID(),
            element: .game(
              Game.State(
                oPlayerName: newGameState.oPlayerName,
                xPlayerName: newGameState.xPlayerName
              )
            )
          )
        )
        return .none

      case .navigation:
        return .none
      }
    }
    .navigationDestination(
      state: /DestinationState.twoFactor,
      action: /DestinationAction.twoFactor
    ) {
      TwoFactor()
    }
    .navigationDestination(
      state: /DestinationState.newGame,
      action: /DestinationAction.newGame
    ) {
      NewGame()
    }
    .navigationDestination(
      state: /DestinationState.game,
      action: /DestinationAction.game
    ) {
      Game()
    }
  }
}
