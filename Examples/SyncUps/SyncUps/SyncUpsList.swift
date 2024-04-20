import ComposableArchitecture
import GRDB
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
    @SharedReader(.syncUps) var syncUps: IdentifiedArrayOf<SyncUp> = []
  }

  enum Action {
    case addSyncUpButtonTapped
    case confirmAddSyncUpButtonTapped
    case delegate(Delegate)
    case destination(PresentationAction<Destination.Action>)
    case dismissAddSyncUpButtonTapped
    case onDelete(IndexSet)
    case syncUpTapped(SharedReader<SyncUp>)

    @CasePathable
    enum Delegate {
      case goToSyncUp(SharedReader<SyncUp>)
    }
  }

  @Dependency(\.defaultDatabaseQueue) var databaseQueue
  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addSyncUpButtonTapped:
        state.destination = .add(
          SyncUpForm.State(
            syncUp: SyncUp()
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
              ?? Attendee(id: Attendee.ID(uuid()))
          )
        }
        state.destination = nil
        return .run { [syncUp] _ in
          try await databaseQueue.write { db in
            try syncUp.insert(db)
          }
        }

      case .delegate:
        return .none

      case .destination:
        return .none

      case .dismissAddSyncUpButtonTapped:
        state.destination = nil
        return .none

      case let .onDelete(indexSet):
        let ids = indexSet.map { state.syncUps[$0].id }
        return .run { _ in
          try await databaseQueue.write { db in
            _ = try SyncUp.deleteAll(db, ids: ids)
          }
        }

      case let .syncUpTapped($syncUp):
        return .send(.delegate(.goToSyncUp($syncUp)))
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
        Button {
          store.send(.syncUpTapped($syncUp))
        } label: {
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
      Text(syncUp.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(syncUp.attendees.count)", systemImage: "person.3")
        Spacer()
        Label(syncUp.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(syncUp.theme.accentColor)
  }
}

struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: LabelStyleConfiguration) -> some View {
    HStack {
      configuration.title
      configuration.icon
    }
  }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
  static var trailingIcon: Self { Self() }
}

#Preview("List") {
  @SharedReader(.syncUps) var syncUps: IdentifiedArrayOf<SyncUp> = [
    .mock,
    .productMock,
    .engineeringMock
  ]
  return NavigationStack {
    SyncUpsListView(
      store: Store(initialState: SyncUpsList.State()) {
        SyncUpsList()
      }
    )
  }
}

#Preview("Card") {
  CardView(
    syncUp: SyncUp(
      attendees: [],
      minutes: 1,
      theme: .bubblegum,
      title: "Point-Free Morning Sync"
    )
  )
}
