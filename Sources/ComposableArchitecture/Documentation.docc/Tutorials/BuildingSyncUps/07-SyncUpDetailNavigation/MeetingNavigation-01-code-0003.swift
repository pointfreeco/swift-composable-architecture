import SwiftUI

struct MeetingView: View {
  let meeting: Meeting
  let syncUp: SyncUp

  var body: some View {
    Form {
      Section {
        ForEach(syncUp.attendees) { attendee in
          Text(attendee.name)
        }
      } header: {
        Text("Attendees")
      }
      Section {
        Text(meeting.transcript)
      } header: {
        Text("Transcript")
      }
    }
    .navigationTitle(Text(meeting.date, style: .date))
  }
}

extension SyncUp {
  static let mock = Self(
    id: SyncUp.ID(),
    attendees: [
      Attendee(id: Attendee.ID(), name: "Blob"),
      Attendee(id: Attendee.ID(), name: "Blob Jr"),
      Attendee(id: Attendee.ID(), name: "Blob Sr"),
    ],
    duration: .seconds(60),
    meetings: [
      Meeting(
        id: Meeting.ID(),
        date: Date().addingTimeInterval(-60 * 60 * 24 * 7),
        transcript: """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          …
          """
      )
    ],
    theme: .orange,
    title: "Design"
  )
}

#Preview {
  MeetingView(meeting: SyncUp.mock.meetings[0], syncUp: .mock)
}
