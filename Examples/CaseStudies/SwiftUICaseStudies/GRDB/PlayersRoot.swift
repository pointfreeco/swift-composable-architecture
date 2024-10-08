import ComposableArchitecture
import GRDB
import SwiftUI

struct PlayersRootView: View {
  static let store = Store(initialState: PlayersListFeature.State()) {
    PlayersListFeature()
  } withDependencies: {
    $0.defaultDatabase = try! DatabaseQueue(
      path: URL.documentsDirectory.appendingPathComponent("db.sqlite").path
    )
    try! $0.defaultDatabase.migrate()
  }

  var body: some View {
    PlayersListView(store: Self.store)
  }
}

#Preview {
  PlayersListView(
    store: Store(initialState: PlayersListFeature.State()) {
      PlayersListFeature()
    } withDependencies: {
      try! $0.defaultDatabase.migrate()
      for idx in 1...20 {
        _ = try! $0.defaultDatabase.write { db in
          try Player(name: "Player \(idx)", score: .random(in: 1...100))
            .inserted(db)
        }
      }
    }
  )
}
