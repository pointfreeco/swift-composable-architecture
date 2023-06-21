import ComposableArchitecture
import SwiftUI

struct MeetingReducer: ReducerProtocol {
  struct State: Equatable {
    let meeting: Meeting
    let standup: Standup
  }
  enum Action: Equatable {}
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  }
}

struct MeetingView: View {
  let store: StoreOf<MeetingReducer>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      ScrollView {
        VStack(alignment: .leading) {
          Divider()
            .padding(.bottom)
          Text("Attendees")
            .font(.headline)
          ForEach(viewStore.standup.attendees) { attendee in
            Text(attendee.name)
          }
          Text("Transcript")
            .font(.headline)
            .padding(.top)
          Text(viewStore.meeting.transcript)
        }
      }
      .navigationTitle(Text(viewStore.meeting.date, style: .date))
      .padding()
    }
  }
}
