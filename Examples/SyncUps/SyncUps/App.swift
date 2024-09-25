import ComposableArchitecture
import OSLog
import GRDB
import SwiftUI

@main
struct SyncUpsApp: App {
  // NB: This is static to avoid interference with Xcode previews, which create this entry
  //     point each time they are run.
  @MainActor
  static let store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  } withDependencies: {
    if ProcessInfo.processInfo.environment["UITesting"] != "true" {
      let logger = Logger(subsystem: "GRDB", category: "Trace")
      var configuration = Configuration()
      configuration.prepareDatabase { db in
        db.trace { logger.debug("\($0)") }
      }
      $0.defaultDatabaseQueue = try! DatabaseQueue(
        path: dump(URL.documentsDirectory.appending(path: "db.sqlite").path),
        configuration: configuration
      )
    } else {
      $0.defaultDatabaseQueue = try! DatabaseQueue()
    }
    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create sync-ups") { db in
      try db.create(table: SyncUp.databaseTableName) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("attendees", .jsonText)
        t.column("meetings", .jsonText)
        t.column("minutes", .integer)
        t.column("theme", .text)
        t.column("title", .text)
      }
    }
    migrator.registerMigration("Create meetings") { db in
      try db.create(table: Meeting.databaseTableName) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("date", .datetime)
        t.column("isArchived", .boolean)
        t.column("syncUpID", .integer)
        t.column("transcript", .text)
      }
    }
    try? migrator.migrate($0.defaultDatabaseQueue)
  }

  var body: some Scene {
    WindowGroup {
      if _XCTIsTesting {
        // NB: Don't run application in tests to avoid interference between the app and the test.
        EmptyView()
      } else {
        AppView(store: Self.store)
      }
    }
  }
}
