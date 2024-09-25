import ComposableArchitecture
import GRDB
import SwiftUI

@main
struct TodosApp: App {
  @MainActor
  static let store = Store(initialState: Todos.State()) {
    Todos()
  } withDependencies: {
    $0.defaultDatabaseQueue = try! DatabaseQueue(
      path: URL.documentsDirectory.appending(path: "db.sqlite").path
    )
    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create todos") { db in
      try db.create(table: "todo") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("description", .text)
        t.column("isComplete", .boolean)
      }
    }
    try? migrator.migrate($0.defaultDatabaseQueue)
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: Self.store)
    }
  }
}
