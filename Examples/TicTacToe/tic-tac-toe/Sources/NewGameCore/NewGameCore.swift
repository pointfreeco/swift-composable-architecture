import ComposableArchitecture
import GameCore

@Reducer
public struct NewGame {
  @ObservableState
  public struct State: Equatable {
    @Presents public var game: Game.State?
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    case game(PresentationAction<Game.Action>)
    case letsPlayButtonTapped
    case logoutButtonTapped
  }

  public init() {}

  public var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
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
      }
    }
    .ifLet(\.$game, action: \.game) {
      Game()
    }
  }
}
