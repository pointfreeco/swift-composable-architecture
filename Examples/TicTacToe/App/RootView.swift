import AppCore
import AppSwiftUI
import AppUIKit
import AuthenticationClientLive
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to build a moderately complex application in the Composable \
  Architecture.

  It includes a login with two-factor authentication, navigation flows, side effects, game logic, \
  and a full test suite.

  This application is super-modularized to demonstrate that it's possible. The core business logic \
  for each screen is put into its own module, and each view is put into its own module.

  Further, the app has been built in both SwiftUI and UIKit to demonstrate how the patterns \
  translate for each platform. The core business logic is only written a single time, and both \
  SwiftUI and UIKit are run from those modules by adapting their domain to the domain that makes \
  most sense for each platform.
  """

enum GameType: Identifiable {
  case swiftui
  case uikit
  var id: Self { self }
}

struct RootView: View {
  let store = Store(initialState: TicTacToe.State()) {
    TicTacToe()._printChanges()
  }

  @State var showGame: GameType?

  var body: some View {
    NavigationStack {
      Form {
        Text(readMe)

        Section {
          Button("SwiftUI version") { self.showGame = .swiftui }
          Button("UIKit version") { self.showGame = .uikit }
        }
      }
      .sheet(item: self.$showGame) { gameType in
        if gameType == .swiftui {
          AppView(store: self.store)
        } else {
          UIKitAppView(store: self.store)
        }
      }
      .navigationTitle("Tic-Tac-Toe")
    }
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
