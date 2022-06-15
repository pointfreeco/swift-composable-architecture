import ComposableArchitecture
import GameCore

public struct NewGame: ReducerProtocol {
  public struct State: Hashable {
    public var game: Game.State?
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action: Hashable {
    case game(Game.Action)
    case gameDismissed
    case letsPlayButtonTapped
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Pullback(state: \.game, action: /Action.game) {
      IfLetReducer {
        Game()
      }
    }

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
        state.game = .init(
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
  }
}
