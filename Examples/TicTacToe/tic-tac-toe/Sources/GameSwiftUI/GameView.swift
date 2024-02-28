import ComposableArchitecture
import GameCore
import SwiftUI

public struct GameView: View {
  let store: StoreOf<Game>

  public init(store: StoreOf<Game>) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0.0) {
        VStack {
          Text(store.title)
            .font(.title)

          if store.isPlayAgainButtonVisible {
            Button("Play again?") {
              store.send(.playAgainButtonTapped)
            }
            .padding(.top, 12)
            .font(.title)
          }
        }
        .padding(.bottom, 48)

        VStack {
          rowView(row: 0, proxy: proxy)
          rowView(row: 1, proxy: proxy)
          rowView(row: 2, proxy: proxy)
        }
        .disabled(store.isGameDisabled)
      }
      .navigationTitle("Tic-tac-toe")
      .navigationBarItems(leading: Button("Quit") { store.send(.quitButtonTapped) })
      .navigationBarBackButtonHidden(true)
    }
  }

  func rowView(
    row: Int,
    proxy: GeometryProxy
  ) -> some View {
    HStack(spacing: 0.0) {
      cellView(row: row, column: 0, proxy: proxy)
      cellView(row: row, column: 1, proxy: proxy)
      cellView(row: row, column: 2, proxy: proxy)
    }
  }

  func cellView(
    row: Int,
    column: Int,
    proxy: GeometryProxy
  ) -> some View {
    Button {
      store.send(.cellTapped(row: row, column: column))
    } label: {
      Text(store.rows[row][column])
        .frame(width: proxy.size.width / 3, height: proxy.size.width / 3)
        .background(
          (row + column).isMultiple(of: 2)
            ? Color(red: 0.8, green: 0.8, blue: 0.8)
            : Color(red: 0.6, green: 0.6, blue: 0.6)
        )
    }
  }
}

extension Game.State {
  fileprivate var rows: [[String]] { self.board.map { $0.map { $0?.label ?? "" } } }
  fileprivate var isGameDisabled: Bool { self.board.hasWinner || self.board.isFilled }
  fileprivate var isPlayAgainButtonVisible: Bool { self.board.hasWinner || self.board.isFilled }
  fileprivate var title: String {
    self.board.hasWinner
      ? "Winner! Congrats \(self.currentPlayerName)!"
      : self.board.isFilled
        ? "Tied game!"
        : "\(self.currentPlayerName), place your \(self.currentPlayer.label)"
  }
}

#Preview {
  NavigationStack {
    GameView(
      store: Store(initialState: Game.State(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr.")) {
        Game()
      }
    )
  }
}
