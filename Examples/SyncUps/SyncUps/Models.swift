import IdentifiedCollections
import SwiftUI
import Tagged

@Observable
class SyncUp: Equatable, Identifiable, Codable {
  let id: Tagged<SyncUp, UUID>
  var attendees: IdentifiedArrayOf<Attendee>
  var duration: Duration
  var meetings: IdentifiedArrayOf<Meeting>
  var theme: Theme
  var title: String

  enum CodingKeys: String, CodingKey {
    case id
    case _attendees = "attendees"
    case _duration = "duration"
    case _meetings = "meetings"
    case _theme = "theme"
    case _title = "title"
  }

  var durationPerAttendee: Duration {
    self.duration / self.attendees.count
  }

  init(
    id: Tagged<SyncUp, UUID>,
    attendees: IdentifiedArrayOf<Attendee> = [] ,
    duration: Duration = .seconds(60 * 5),
    meetings: IdentifiedArrayOf<Meeting> = [],
    theme: Theme = .bubblegum,
    title: String = ""
  ) {
    self.id = id
    self.attendees = attendees
    self.duration = duration
    self.meetings = meetings
    self.theme = theme
    self.title = title
  }

  func copy() -> SyncUp {
    SyncUp(
      id: self.id,
      attendees: self.attendees,
      duration: self.duration,
      meetings: self.meetings,
      theme: self.theme,
      title: self.title
    )
  }
  
  func update(_ other: SyncUp) {
    precondition(self.id == other.id)
    self.attendees = other.attendees
    self.duration = other.duration
    self.meetings = other.meetings
    self.theme = other.theme
    self.title = other.title
  }

  static func == (lhs: SyncUp, rhs: SyncUp) -> Bool {
    lhs === rhs
  }
}

struct Attendee: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  var name = ""
}

struct Meeting: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  let date: Date
  var transcript: String
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

  var mainColor: Color { Color(self.rawValue) }

  var name: String { self.rawValue.capitalized }
}

extension SyncUp {
  static let mock = SyncUp(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Esq"),
      Attendee(id: Attendee.ID(), name: "Blob III"),
      Attendee(id: Attendee.ID(), name: "Blob I"),
    ],
    duration: .seconds(60),
    meetings: [
      Meeting(
        id: Meeting.ID(),
        date: Date().addingTimeInterval(-60 * 60 * 24 * 7),
        transcript: """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
          dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. \
          Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
          mollit anim id est laborum.
          """
      )
    ],
    theme: .orange,
    title: "Point-Free morning sync"
  )

  static let engineeringMock = SyncUp(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: .seconds(60 * 10),
    theme: .periwinkle,
    title: "Engineering"
  )

  static let designMock = SyncUp(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: .seconds(60 * 30),
    theme: .poppy,
    title: "Product"
  )
}
