import ComposableArchitecture
import GameCore
import SwiftUI

extension Game.State {
  var isGameDisabled: Bool {
    self.board.hasWinner || self.board.isFilled
  }

  var isPlayAgainButtonVisible: Bool {
    self.board.hasWinner || self.board.isFilled
  }

  var title: String {
    self.board.hasWinner
    ? "Winner! Congrats \(self.currentPlayerName)!"
    : self.board.isFilled
      ? "Tied game!"
      : "\(self.currentPlayerName), place your \(self.currentPlayer.label)"
  }
}

public struct GameView: View {
  @State var store: StoreOf<Game>

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
          self.rowView(row: 0, proxy: proxy)
          self.rowView(row: 1, proxy: proxy)
          self.rowView(row: 2, proxy: proxy)
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
      self.cellView(row: row, column: 0, proxy: proxy)
      self.cellView(row: row, column: 1, proxy: proxy)
      self.cellView(row: row, column: 2, proxy: proxy)
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
      Text(store.board[row][column]?.label ?? "")
        .frame(width: proxy.size.width / 3, height: proxy.size.width / 3)
        .background(
          (row + column).isMultiple(of: 2)
            ? Color(red: 0.8, green: 0.8, blue: 0.8)
            : Color(red: 0.6, green: 0.6, blue: 0.6)
        )
    }
  }
}

struct Game_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      GameView(
        store: Store(initialState: Game.State(oPlayerName: "Blob Jr.", xPlayerName: "Blob Sr.")) {
          Game()
        }
      )
    }
  }
}
