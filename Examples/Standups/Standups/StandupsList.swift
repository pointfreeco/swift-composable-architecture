import ComposableArchitecture
import SwiftUI

struct StandupsList: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var destination: Destination.State?
    var standups: IdentifiedArrayOf<Standup> = []

    init(
      destination: Destination.State? = nil
    ) {
      self.destination = destination

      do {
        @Dependency(\.dataManager.load) var load
        self.standups = try JSONDecoder().decode(IdentifiedArray.self, from: load(.standups))
      } catch is DecodingError {
        self.destination = .alert(.dataFailedToLoad)
      } catch {
      }
    }
  }
  enum Action: Equatable {
    case addStandupButtonTapped
    case confirmAddStandupButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case dismissAddStandupButtonTapped
  }
  struct Destination: ReducerProtocol {
    enum State: Equatable {
      case add(StandupForm.State)
      case alert(AlertState<Action.Alert>)
    }

    enum Action: Equatable {
      case add(StandupForm.Action)
      case alert(Alert)

      enum Alert {
        case confirmLoadMockData
      }
    }

    var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.add, action: /Action.add) {
        StandupForm()
      }
    }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addStandupButtonTapped:
        state.destination = .add(StandupForm.State(standup: Standup(id: Standup.ID(self.uuid()))))
        return .none

      case .confirmAddStandupButtonTapped:
        guard case let .some(.add(editState)) = state.destination
        else { return .none }
        var standup = editState.standup
        standup.attendees.removeAll { attendee in
          attendee.name.allSatisfy(\.isWhitespace)
        }
        if standup.attendees.isEmpty {
          standup.attendees.append(
            editState.standup.attendees.first
              ?? Attendee(id: Attendee.ID(self.uuid()))
          )
        }
        state.standups.append(standup)
        state.destination = nil
        return .none

      case .destination(.presented(.alert(.confirmLoadMockData))):
        state.standups = [
          .mock,
          .designMock,
          .engineeringMock,
        ]
        return .none

      case .destination:
        return .none

      case .dismissAddStandupButtonTapped:
        state.destination = nil
        return .none
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }
  }
}

struct StandupsListView: View {
  let store: StoreOf<StandupsList>

  var body: some View {
    WithViewStore(self.store, observe: \.standups) { viewStore in
      List {
        ForEach(viewStore.state) { standup in
          NavigationLink(
            state: AppFeature.Path.State.detail(StandupDetail.State(standup: standup))
          ) {
            CardView(standup: standup)
          }
          .listRowBackground(standup.theme.mainColor)
        }
      }
      .toolbar {
        Button {
          viewStore.send(.addStandupButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      .navigationTitle("Daily Standups")
      .alert(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /StandupsList.Destination.State.alert,
        action: StandupsList.Destination.Action.alert
      )
      .sheet(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /StandupsList.Destination.State.add,
        action: StandupsList.Destination.Action.add
      ) { store in
        NavigationStack {
          StandupFormView(store: store)
            .navigationTitle("New standup")
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Dismiss") {
                  viewStore.send(.dismissAddStandupButtonTapped)
                }
              }
              ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                  viewStore.send(.confirmAddStandupButtonTapped)
                }
              }
            }
        }
      }
    }
  }
}

extension AlertState where Action == StandupsList.Destination.Action.Alert {
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
  let standup: Standup

  var body: some View {
    VStack(alignment: .leading) {
      Text(self.standup.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(self.standup.attendees.count)", systemImage: "person.3")
        Spacer()
        Label(self.standup.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(self.standup.theme.accentColor)
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

struct StandupsList_Previews: PreviewProvider {
  static var previews: some View {
    StandupsListView(
      store: Store(initialState: StandupsList.State()) {
        StandupsList()
      } withDependencies: {
        $0.dataManager.load = { _ in
          try JSONEncoder().encode([
            Standup.mock,
            .designMock,
            .engineeringMock,
          ])
        }
      }
    )

    StandupsListView(
      store: Store(initialState: StandupsList.State()) {
        StandupsList()
      } withDependencies: {
        $0.dataManager = .mock(initialData: Data("!@#$% bad data ^&*()".utf8))
      }
    )
    .previewDisplayName("Load data failure")
  }
}
