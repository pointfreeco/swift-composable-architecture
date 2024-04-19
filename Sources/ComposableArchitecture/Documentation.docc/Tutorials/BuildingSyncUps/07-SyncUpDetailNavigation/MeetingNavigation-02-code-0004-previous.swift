import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  // ...
}

struct SyncUpDetail.Destination {
  // ...
}

struct SyncUpDetailView: View {
  @Bindable var store: StoreOf<SyncUpDetail>

  var body: some View {
    Form {
      Section {
        Button {
          store.send(.startMeetingButtonTapped)
        } label: {
          Label("Start Meeting", systemImage: "timer")
            .font(.headline)
            .foregroundColor(.accentColor)
        }
        HStack {
          Label("Length", systemImage: "clock")
          Spacer()
          Text(store.syncUp.duration.formatted(.units()))
        }

        HStack {
          Label("Theme", systemImage: "paintpalette")
          Spacer()
          Text(store.syncUp.theme.name)
            .padding(4)
            .foregroundColor(store.syncUp.theme.accentColor)
            .background(store.syncUp.theme.mainColor)
            .cornerRadius(4)
        }
      } header: {
        Text("Sync-up Info")
      }

      if !store.syncUp.meetings.isEmpty {
        Section {
          ForEach(store.syncUp.meetings) { meeting in
            Button {
            } label: {
              HStack {
                Image(systemName: "calendar")
                Text(meeting.date, style: .date)
                Text(meeting.date, style: .time)
              }
            }
          }
        } header: {
          Text("Past meetings")
        }
      }

      Section {
        ForEach(store.syncUp.attendees) { attendee in
          Label(attendee.name, systemImage: "person")
        }
      } header: {
        Text("Attendees")
      }

      Section {
        Button("Delete") {
          store.send(.deleteButtonTapped)
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
      }
    }
    .toolbar {
      Button("Edit") {
        store.send(.editButtonTapped)
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .sheet(
      item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
    ) { editSyncUpStore in
      NavigationStack {
        SyncUpFormView(store: editSyncUpStore)
          .navigationTitle(store.syncUp.title)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
                store.send(.cancelEditButtonTapped)
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                store.send(.doneEditingButtonTapped)
              }
            }
          }
      }
  }
}

#Preview {
  NavigationStack {
    SyncUpDetailView(
      store: Store(
        initialState: SyncUpDetail.State(
          syncUp: Shared(
            SyncUp(
              id: SyncUp.ID(),
              attendees: [
                Attendee(id: Attendee.ID(), name: "Blob"),
                Attendee(id: Attendee.ID(), name: "Blob Jr."),
                Attendee(id: Attendee.ID(), name: "Blob Sr."),
              ],
              title: "Point-Free Morning Sync"
            )
          )
        )
      ) {
        SyncUpDetail()
      }
    )
  }
}
