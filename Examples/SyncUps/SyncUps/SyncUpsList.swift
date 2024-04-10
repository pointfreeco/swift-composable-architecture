import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  @Reducer(state: .equatable)
  enum Destination {
    case add(SyncUpForm)
    case alert(AlertState<Alert>)

    @CasePathable
    enum Alert {
      case confirmLoadMockData
    }
  }

  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    @Shared(.syncUps) var syncUps: IdentifiedArrayOf<SyncUp> = []
  }

  enum Action {
    case addSyncUpButtonTapped
    case confirmAddSyncUpButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case dismissAddSyncUpButtonTapped
    case onDelete(IndexSet)
  }

  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addSyncUpButtonTapped:
        state.destination = .add(
          SyncUpForm.State(
            syncUp: SyncUp(id: SyncUp.ID(self.uuid()))
          )
        )
        return .none

      case .confirmAddSyncUpButtonTapped:
        guard case let .some(.add(editState)) = state.destination
        else { return .none }
        var syncUp = editState.syncUp
        syncUp.attendees.removeAll { attendee in
          attendee.name.allSatisfy(\.isWhitespace)
        }
        if syncUp.attendees.isEmpty {
          syncUp.attendees.append(
            editState.syncUp.attendees.first
              ?? Attendee(id: Attendee.ID(self.uuid()))
          )
        }
        state.syncUps.append(syncUp)
        state.destination = nil
        return .none

      case .destination:
        return .none

      case .dismissAddSyncUpButtonTapped:
        state.destination = nil
        return .none

      case let .onDelete(indexSet):
        state.syncUps.remove(atOffsets: indexSet)
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

struct SyncUpsListView: View {
  @Bindable var store: StoreOf<SyncUpsList>

  var body: some View {
    List {
      ForEach(store.$syncUps.elements) { $syncUp in
        NavigationLink(state: AppFeature.Path.State.detail(SyncUpDetail.State(syncUp: $syncUp))) {
          CardView(syncUp: syncUp)
        }
        .listRowBackground(syncUp.theme.mainColor)
      }
      .onDelete { indexSet in
        store.send(.onDelete(indexSet))
      }
    }
    .toolbar {
      Button {
        store.send(.addSyncUpButtonTapped)
      } label: {
        Image(systemName: "plus")
      }
    }
    .navigationTitle("Daily Sync-ups")
    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
      NavigationStack {
        SyncUpFormView(store: store)
          .navigationTitle("New sync-up")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Dismiss") {
                self.store.send(.dismissAddSyncUpButtonTapped)
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Add") {
                self.store.send(.confirmAddSyncUpButtonTapped)
              }
            }
          }
      }
    }
  }
}

struct CardView: View {
  let syncUp: SyncUp

  var body: some View {
    VStack(alignment: .leading) {
      Text(self.syncUp.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(self.syncUp.attendees.count)", systemImage: "person.3")
        Spacer()
        Label(self.syncUp.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(self.syncUp.theme.accentColor)
  }
}

struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.title
      configuration.icon
    }
  }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
  static var trailingIcon: Self { Self() }
}

struct SyncUpsList_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      SyncUpsListView(
        store: Store(
          initialState: SyncUpsList.State(
            syncUps: [
              .mock,
              .productMock,
              .engineeringMock,
            ]
          )
        ) {
          SyncUpsList()
        }
      )
    }
  }
}

#Preview("Card") {
  CardView(
    syncUp: SyncUp(
      id: SyncUp.ID(),
      attendees: [],
      duration: .seconds(60),
      meetings: [],
      theme: .bubblegum,
      title: "Point-Free Morning Sync"
    )
  )
}

extension PersistenceKey where Self == FileStorageKey<IdentifiedArrayOf<SyncUp>> {
  static var syncUps: Self {
    fileStorage(.documentsDirectory.appending(component: "sync-ups.json"))
  }
}
