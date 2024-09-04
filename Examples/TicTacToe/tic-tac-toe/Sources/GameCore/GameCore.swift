import ComposableArchitecture
import SwiftUI

@Reducer
public struct Game: Sendable {
  @ObservableState
  public struct State: Equatable {
    public var board: Three<Three<Player?>> = .empty
    public var currentPlayer: Player = .x
    public let oPlayerName: String
    public let xPlayerName: String

    public init(oPlayerName: String, xPlayerName: String) {
      self.oPlayerName = oPlayerName
      self.xPlayerName = xPlayerName
    }

    public var currentPlayerName: String {
      switch self.currentPlayer {
      case .o: return self.oPlayerName
      case .x: return self.xPlayerName
      }
    }
  }

  public enum Action: Sendable {
    case cellTapped(row: Int, column: Int)
    case playAgainButtonTapped
    case quitButtonTapped
  }

  @Dependency(\.dismiss) var dismiss

  public init() {}

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .cellTapped(row, column):
        guard
          state.board[row][column] == nil,
          !state.board.hasWinner
        else { return .none }

        state.board[row][column] = state.currentPlayer

        if !state.board.hasWinner {
          state.currentPlayer.toggle()
        }

        return .none

      case .playAgainButtonTapped:
        state = Game.State(oPlayerName: state.oPlayerName, xPlayerName: state.xPlayerName)
        return .none

      case .quitButtonTapped:
        return .run { _ in
          await self.dismiss()
        }
      }
    }
  }
}

public enum Player: Equatable, Sendable {
  case o
  case x

  public mutating func toggle() {
    switch self {
    case .o: self = .x
    case .x: self = .o
    }
  }

  public var label: String {
    switch self {
    case .o: return "⭕️"
    case .x: return "❌"
    }
  }
}

extension Three<Three<Player?>> {
  public static let empty = Self(
    .init(nil, nil, nil),
    .init(nil, nil, nil),
    .init(nil, nil, nil)
  )

  public var isFilled: Bool {
    self.allSatisfy { $0.allSatisfy { $0 != nil } }
  }

  func hasWin(_ player: Player) -> Bool {
    let winConditions = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [6, 4, 2],
    ]

    for condition in winConditions {
      let matches =
        condition
        .map { self[$0 % 3][$0 / 3] }
      let matchCount =
        matches
        .filter { $0 == player }
        .count

      if matchCount == 3 {
        return true
      }
    }
    return false
  }

  public var hasWinner: Bool {
    hasWin(.x) || hasWin(.o)
  }
}
