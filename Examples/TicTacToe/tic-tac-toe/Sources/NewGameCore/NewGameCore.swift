import ComposableArchitecture

public struct NewGame: ReducerProtocol {
  public struct State: Hashable {
    public var oPlayerName = ""
    public var xPlayerName = ""

    public init() {}
  }

  public enum Action: Hashable {
    case letsPlayButtonTapped
    case oPlayerNameChanged(String)
    case xPlayerNameChanged(String)
  }

  public init() {}

  public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .letsPlayButtonTapped:
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
