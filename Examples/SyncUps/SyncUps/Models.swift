import IdentifiedCollections
import SwiftUI
import Tagged
import SwiftData

@Model
class SyncUp {
  var attendees: IdentifiedArrayOf<Attendee>
  var duration: Int
  var meetings: IdentifiedArrayOf<Meeting>
  var theme: Theme
  var title: String

  var durationPerAttendee: TimeInterval {
    Double(self.duration) / Double(self.attendees.count)
  }

  init(
    attendees: IdentifiedArrayOf<Attendee> = [] ,
    duration: Int = 60 * 5,
    meetings: IdentifiedArrayOf<Meeting> = [],
    theme: Theme = .bubblegum,
    title: String = ""
  ) {
    self.attendees = attendees
    self.duration = duration
    self.meetings = meetings
    self.theme = theme
    self.title = title
  }

  func copy() -> SyncUp {
    SyncUp(
      attendees: self.attendees,
      duration: self.duration,
      meetings: self.meetings,
      theme: self.theme,
      title: self.title
    )
  }
  
  func update(_ other: SyncUp) {
    self.attendees = other.attendees
    self.duration = other.duration
    self.meetings = other.meetings
    self.theme = other.theme
    self.title = other.title
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
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Esq"),
      Attendee(id: Attendee.ID(), name: "Blob III"),
      Attendee(id: Attendee.ID(), name: "Blob I"),
    ],
    duration: 60,
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
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: 60 * 10,
    theme: .periwinkle,
    title: "Engineering"
  )

  static let designMock = SyncUp(
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: 60 * 30,
    theme: .poppy,
    title: "Product"
  )
}
