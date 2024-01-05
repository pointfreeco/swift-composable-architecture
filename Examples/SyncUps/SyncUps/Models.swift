import IdentifiedCollections
import SwiftUI
import Tagged

// TODO: make unchecked sendable with a lock

import Dependencies

// @Dependency(Ref<Settings>.self) settings

// TODO: Other names: Shared, ObservableRef,
@dynamicMemberLookup
@Observable
final class Ref<Value> {
  var value: Value
  init(_ value: Value) {
    self.value = value
  }
  subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
    get { self.value[keyPath: keyPath] }
    set { self.value[keyPath: keyPath] = newValue }
  }
  func copy() -> Ref<Value> {
    Ref(self.value)
  }
}
extension Ref: Equatable {
  static func == (lhs: Ref, rhs: Ref) -> Bool {
    lhs === rhs
  }
}
extension Ref: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
// TODO: try reference identity
extension Ref: Identifiable where Value: Identifiable {
  var id: Value.ID {
    self.value.id
  }
}
extension Ref: Codable where Value: Codable {
  convenience init(from decoder: Decoder) throws {
    do {
      self.init(try decoder.singleValueContainer().decode(Value.self))
    } catch {
      self.init(try .init(from: decoder))
    }
  }
  func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.value)
    } catch {
      try self.value.encode(to: encoder)
    }
  }
}

struct SyncUp: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  var attendees: IdentifiedArrayOf<Attendee> = []
  var duration: Duration = .seconds(60 * 5)
  var meetings: IdentifiedArrayOf<Meeting> = []
  var theme: Theme = .bubblegum
  var title = ""

  var durationPerAttendee: Duration {
    self.duration / self.attendees.count
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
  static let mock = Self(
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

  static let engineeringMock = Self(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
    ],
    duration: .seconds(60 * 10),
    theme: .periwinkle,
    title: "Engineering"
  )

  static let designMock = Self(
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
