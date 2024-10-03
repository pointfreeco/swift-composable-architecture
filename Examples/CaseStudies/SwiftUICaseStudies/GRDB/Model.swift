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

extension PersistenceReaderKey where Self == GRDBQueryKey<PlayersRequest> {
  static func players(order: PlayersRequest.Order) -> Self {
    .query(PlayersRequest(order: order))
  }
}

struct PlayersRequest: GRDBQuery {
  enum Order {
    case name
    case score
  }

  let order: Order

  func fetch(_ db: Database) throws -> [Player] {
    let order: [any SQLOrderingTerm] = switch order {
    case .name:
      [
        Column("name").collating(.localizedCaseInsensitiveCompare)
      ]
    case .score:
      [
        Column("score").desc,
        Column("name").collating(.localizedCaseInsensitiveCompare)
      ]
    }

    return try Player.all()
      .order(order)
      .fetchAll(db)
  }
}
