import ComposableArchitecture
import GRDB
import SwiftUI

struct PlayersNavigationView: View {
  static let store = Store(initialState: PlayersListFeature.State()) {
    PlayersListFeature()
  } withDependencies: {
    let database = try! DatabaseQueue()
    var migrator = DatabaseMigrator()
    #if DEBUG
      migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("v1") { db in
      try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
      }
    }
    try! migrator.migrate(database)
    $0.defaultDatabase = database
  }

  var body: some View {
    PlayersListView(store: Self.store)
  }
}

#Preview {
  PlayersNavigationView()
}
