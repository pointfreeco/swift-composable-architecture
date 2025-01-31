import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  // ...
}

struct SyncUpDetailView: View {
  @Bindable var store: StoreOf<SyncUpDetail>

  var body: some View {
    Form {
      Section {
        NavigationLink {
        } label: {
          Label("Start Meeting", systemImage: "timer")
            .font(.headline)
            .foregroundStyle(Color.accentColor)
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
            .foregroundStyle(store.syncUp.theme.accentColor)
            .background(store.syncUp.theme.mainColor)
            .clipShape(.rect(cornerRadius: 4))
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
        Button("Delete", role: .destructive) {
          store.send(.deleteButtonTapped)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(Text(store.syncUp.title))
    .toolbar {
      Button("Edit") {
        store.send(.editButtonTapped)
      }
    }
    .sheet(item: $store.scope(state: \.editSyncUp, action: \.editSyncUp)) { editSyncUpStore in
      NavigationStack {
        SyncUpFormView(store: editSyncUpStore)
          .navigationTitle(store.syncUp.title)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
              }
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
          syncUp: Shared(value: .mock)
        )
      ) {
        SyncUpDetail()
      }
    )
  }
}
