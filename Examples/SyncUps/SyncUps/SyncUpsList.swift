import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  struct State: Equatable {
    @PresentationState var destination: Destination.State?
    var syncUps: IdentifiedArrayOf<SyncUp> = []

    init(
      destination: Destination.State? = nil
    ) {
      self.destination = destination

      do {
        @Dependency(\.dataManager.load) var load
        self.syncUps = try JSONDecoder().decode(IdentifiedArray.self, from: load(.syncUps))
      } catch is DecodingError {
        self.destination = .alert(.dataFailedToLoad)
      } catch {
      }
    }
  }

  enum Action {
    case addSyncUpButtonTapped
    case confirmAddSyncUpButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case dismissAddSyncUpButtonTapped
  }

  @Reducer
  struct Destination {
    enum State: Equatable {
      case add(SyncUpForm.State)
      case alert(AlertState<Action.Alert>)
    }

    enum Action {
      case add(SyncUpForm.Action)
      case alert(Alert)

      enum Alert {
        case confirmLoadMockData
      }
    }

    var body: some ReducerOf<Self> {
      Scope(state: \.add, action: \.add) {
        SyncUpForm()
      }
    }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addSyncUpButtonTapped:
        state.destination = .add(SyncUpForm.State(syncUp: SyncUp(id: SyncUp.ID(self.uuid()))))
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

      case .destination(.presented(.alert(.confirmLoadMockData))):
        state.syncUps = [
          .mock,
          .designMock,
          .engineeringMock,
        ]
        return .none

      case .destination:
        return .none

      case .dismissAddSyncUpButtonTapped:
        state.destination = nil
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}

struct SyncUpsListView: View {
  let store: StoreOf<SyncUpsList>

  var body: some View {
    WithViewStore(self.store, observe: \.syncUps) { viewStore in
      List {
        ForEach(viewStore.state) { syncUp in
          NavigationLink(
            state: AppFeature.Path.State.detail(SyncUpDetail.State(syncUp: syncUp))
          ) {
            CardView(syncUp: syncUp)
          }
          .listRowBackground(syncUp.theme.mainColor)
        }
      }
      .toolbar {
        Button {
          viewStore.send(.addSyncUpButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      .navigationTitle("Daily Sync-ups")
      .alert(store: self.store.scope(state: \.$destination.alert, action: \.destination.alert))
      .sheet(
        store: self.store.scope(state: \.$destination.add, action: \.destination.add)
      ) { store in
        NavigationStack {
          SyncUpFormView(store: store)
            .navigationTitle("New sync-up")
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Dismiss") {
                  viewStore.send(.dismissAddSyncUpButtonTapped)
                }
              }
              ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                  viewStore.send(.confirmAddSyncUpButtonTapped)
                }
              }
            }
        }
      }
    }
  }
}

extension AlertState where Action == SyncUpsList.Destination.Action.Alert {
  static let dataFailedToLoad = Self {
    TextState("Data failed to load")
  } actions: {
    ButtonState(action: .send(.confirmLoadMockData, animation: .default)) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("No")
    }
  } message: {
    TextState(
      """
      Unfortunately your past data failed to load. Would you like to load some mock data to play \
      around with?
      """
    )
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
    SyncUpsListView(
      store: Store(initialState: SyncUpsList.State()) {
        SyncUpsList()
      } withDependencies: {
        $0.dataManager.load = { @Sendable _ in
          try JSONEncoder().encode([
            SyncUp.mock,
            .designMock,
            .engineeringMock,
          ])
        }
      }
    )

    SyncUpsListView(
      store: Store(initialState: SyncUpsList.State()) {
        SyncUpsList()
      } withDependencies: {
        $0.dataManager = .mock(initialData: Data("!@#$% bad data ^&*()".utf8))
      }
    )
    .previewDisplayName("Load data failure")
  }
}
