import ComposableArchitecture
import GameCore

public struct NewGame: ReducerProtocol {
  public struct State: Equatable {
    @PresentationStateOf<Game> public var game
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action: Equatable {
    case game(PresentationActionOf<Game>)
    case logoutButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .game(.present):
        state.game = Game.State(
          oPlayerName: state.oPlayerName,
          xPlayerName: state.xPlayerName
        )
        return .none

      case .game:
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
    .presentationDestination(\.$game, action: /Action.game) {
      Game()
    }
  }
}
