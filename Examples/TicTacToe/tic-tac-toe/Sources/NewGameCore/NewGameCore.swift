import ComposableArchitecture
import GameCore

public struct NewGame: ReducerProtocol {
  public struct State: Equatable {
    public var game: Game.State?
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action: Equatable {
    case game(Game.Action)
    case gameDismissed
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .game(.quitButtonTapped):
        state.game = nil
        return .none

      case .gameDismissed:
        state.game = nil
        return .none

      case .game:
        return .none

      case .letsPlayButtonTapped:
        state.game = Game.State(
          oPlayerName: state.oPlayerName,
          xPlayerName: state.xPlayerName
        )
        return .none

      case .logoutButtonTapped:
        return .none

      case let .oPlayerNameChanged(name):
        state.oPlayerName = name
        return .none

      case let .xPlayerNameChanged(name):
        state.xPlayerName = name
        return .none
      }
    }
    .ifLet(\.game, action: /NewGame.Action.game) {
      Game()
    }
  }
}
