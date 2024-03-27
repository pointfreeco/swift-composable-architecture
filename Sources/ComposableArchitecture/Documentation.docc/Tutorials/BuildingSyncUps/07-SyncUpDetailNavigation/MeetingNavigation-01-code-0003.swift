import SwiftUI

struct MeetingView: View {
  let meeting: Meeting
  let syncUp: SyncUp

  var body: some View {
    Form {
      Section {
        ForEach(self.syncUp.attendees) { attendee in
          Text(attendee.name)
        }
      } header: {
        Text("Attendees")
      }
      Section {
        Text(self.meeting.transcript)
      } header: {
        Text("Transcript")
      }
    }
    .navigationTitle(Text(self.meeting.date, style: .date))
  }
}

#Preview {
  MeetingView(meeting: SyncUp.mock.meetings[0], syncUp: .mock)
}
