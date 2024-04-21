import ComposableArchitecture
import GRDB
import IdentifiedCollections
import SwiftUI
import Tagged

struct SyncUp: Equatable, Identifiable, Codable {
  var id: Int?
  var attendees: IdentifiedArrayOf<Attendee> = []
  var minutes: Int = 5
  var theme: Theme = .bubblegum
  var title = ""

  var duration: Duration {
    get { .seconds(60 * minutes) }
    set { minutes = Int(newValue.components.seconds) / 60 }
  }

  var durationPerAttendee: Duration {
    duration / attendees.count
  }
}

extension SyncUp: TableRecord, PersistableRecord, FetchableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    self.id = Int(inserted.rowID)
  }
}

extension PersistenceReaderKey where Self == GRDBQueryKey<SyncUpsRequest> {
  static var syncUps: Self {
    .query(SyncUpsRequest())
  }
}

struct SyncUpsRequest: GRDBQuery {
  func fetch(_ db: Database) throws -> IdentifiedArrayOf<SyncUp> {
    try SyncUp.all().order(Column("id").desc).fetchIdentifiedArray(db)
  }
}

struct Attendee: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  var name = ""
}

struct Meeting: Equatable, Identifiable, Codable {
  var id: Int?
  var date: Date
  var isArchived: Bool = false
  var syncUpID: SyncUp.ID
  var transcript: String
}

extension Meeting: TableRecord, PersistableRecord, FetchableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    self.id = Int(inserted.rowID)
  }
}

extension PersistenceReaderKey where Self == GRDBQueryKey<MeetingsRequest> {
  static func meetings(syncUpID: SyncUp.ID, includeArchived: Bool = false) -> Self {
    .query(MeetingsRequest(syncUpID: syncUpID, includeArchived: includeArchived))
  }
}

struct MeetingsRequest: GRDBQuery {
  let syncUpID: SyncUp.ID
  let includeArchived: Bool

  func fetch(_ db: Database) throws -> IdentifiedArrayOf<Meeting> {
    var filter: SQLExpression = Column("syncUpID") == syncUpID
    if !includeArchived {
      filter = filter && !Column("isArchived")
    }
    return try Meeting.all()
      .filter(filter)
      .order(Column("id").desc)
      .fetchIdentifiedArray(db)
  }
}

enum Theme: String, CaseIterable, Equatable, Identifiable, Codable {
  case bubblegum
  case buttercup
  case indigo
  case lavender
  case magenta
  case navy
  case orange
  case oxblood
  case periwinkle
  case poppy
  case purple
  case seafoam
  case sky
  case tan
  case teal
  case yellow

  var id: Self { self }

  var accentColor: Color {
    switch self {
    case .bubblegum, .buttercup, .lavender, .orange, .periwinkle, .poppy, .seafoam, .sky, .tan,
      .teal, .yellow:
      return .black
    case .indigo, .magenta, .navy, .oxblood, .purple:
      return .white
    }
  }

  var mainColor: Color { Color(rawValue) }

  var name: String { rawValue.capitalized }
}

extension SyncUp {
  static let mock = Self(
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Esq"),
      Attendee(id: Attendee.ID(), name: "Blob III"),
      Attendee(id: Attendee.ID(), name: "Blob I"),
    ],
    minutes: 1,
    theme: .orange,
    title: "Design"
  )

  static let engineeringMock = Self(
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    minutes: 10,
    theme: .periwinkle,
    title: "Engineering"
  )

  static let productMock = Self(
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    minutes: 30,
    theme: .poppy,
    title: "Product"
  )
}

extension Meeting {
  static let mock = Self(
    date: Date().addingTimeInterval(-60 * 60 * 24 * 7),
    syncUpID: 1,
    transcript: """
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
      incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
      exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
      dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. \
      Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
      mollit anim id est laborum.
      """
  )
}
