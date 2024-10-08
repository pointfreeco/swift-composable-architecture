import ComposableArchitecture
import GRDB

struct Player: Equatable {
  var id: Int64?
  var name = ""
  var score = 0
}

extension Player: Codable, FetchableRecord, MutablePersistableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }
}

extension DatabaseWriter {
  func migrate() throws {
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
    try migrator.migrate(self)
  }
}
