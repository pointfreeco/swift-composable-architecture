import ComposableArchitecture
import SwiftUI

// TODO: extra app domain to be separate from StandupsList domain so that it doesn't
//       have to depend on any other features. also move presentations to the app
//       level??

struct StandupsList: ReducerProtocol {
  struct State: Equatable {
    @PresentationStateOf<Destinations> var destination
    @NavigationStateOf<Stack> var path  // TODO: path? stack? navigation?
    var standups: IdentifiedArrayOf<Standup> = []

    init(
      destination: Destinations.State? = nil,
      path: NavigationStateOf<Stack>.Path = []
    ) {
      self.destination = destination
      self.path = path

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
    case destination(PresentationActionOf<Destinations>)
    case dismissAddStandupButtonTapped
    case path(NavigationActionOf<Stack>)  // TODO: path? stack? navigation?
    case standupTapped(id: Standup.ID)
  }
  enum AlertAction {
    case confirmLoadMockData
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.dataManager) var dataManager
  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

  struct Destinations: ReducerProtocol {
    enum State: Equatable {
      case add(EditStandup.State)
      case alert(AlertState<AlertAction>)
    }

    enum Action: Equatable {
      case add(EditStandup.Action)
      case alert(AlertAction)
    }

    var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.add, action: /Action.add) {
        EditStandup()
      }
    }
  }

  struct Stack: ReducerProtocol {
    enum State: Hashable {
      case detail(StandupDetail.State)
      case meeting(MeetingReducer.State)
      case record(RecordMeeting.State)
    }

    enum Action: Equatable {
      case detail(StandupDetail.Action)
      case meeting(MeetingReducer.Action)
      case record(RecordMeeting.Action)
    }

    var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.detail, action: /Action.detail) {
        StandupDetail()
      }
      Scope(state: /State.meeting, action: /Action.meeting) {
        MeetingReducer()
      }
      Scope(state: /State.record, action: /Action.record) {
        RecordMeeting()
      }
    }
  }

  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .addStandupButtonTapped:
        state.destination = .add(EditStandup.State(standup: Standup(id: Standup.ID(self.uuid()))))
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

      case let .path(.element(id: id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.$path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteStandup:
          _ = state.path.popLast()
          state.standups.remove(id: detailState.standup.id)
          return .none

        case let .goToMeeting(meeting):
          state.path.append(
            .meeting(
              MeetingReducer.State(
                meeting: meeting,
                standup: detailState.standup
              )
            )
          )
          return .none

        case .startMeeting:
          state.path.append(
            .record(
              RecordMeeting.State(standup: detailState.standup)
            )
          )
          return .none
        }

      case let .path(.element(id: _, .record(.delegate(delegateAction)))):
        switch delegateAction {
        case let .save(transcript: transcript):
          _ = state.path.popLast()
          //_ = state.path.popLast(from: id) // TODO: more popping/pushing helpers on path
          guard 
            let stackDestination = state.$path.last,
            case var .detail(detailState) = stackDestination.element
          else { return .none }

          detailState.standup.meetings.insert(
            Meeting(
              id: Meeting.ID(self.uuid()),
              date: self.now,
              transcript: transcript
            ),
            at: 0
          )
          state.$path[id: stackDestination.id] = .detail(detailState)

          // TODO: possible to make Destinations identifiable? state.$path.update(.detail(detailState))
//          _ = try? (/StandupsList.Stack.State.detail).modify(&state.$path[id: stackDestination.id]) {
//            _ = $0
//          }

          return .none
        }

      case .path:
        return .none

      case let .standupTapped(id: id):
        guard let standup = state.standups[id: id]
        else { return .none }

        state.path.append(
          .detail(
            StandupDetail.State(standup: standup)
          )
        )

        return .none
      }
    }
    .navigationDestination(\.$path, action: /Action.path) {
      Stack()
    }
    .presentationDestination(\.$destination, action: /Action.destination) {
      Destinations()
    }

    // TODO: Should we polish up onChange and use it here?
    Reduce<State, Action> { state, action in
      // NB: Playback any changes made to stand up in detail
      for destination in state.path {
        guard case let .detail(detailState) = destination
        else { continue }
        state.standups[id: detailState.standup.id] = detailState.standup
      }
      
      return .run { [standups = state.standups] _ in
        try await withTaskCancellation(id: "deadbeef", cancelInFlight: true) { // TODO: better ID
          try await self.clock.sleep(for: .seconds(1))
          try await self.dataManager.save(JSONEncoder().encode(standups), .standups)
        }
      } catch: { _, _ in }
    }
  }
}

struct StandupsListView: View {
  let store: StoreOf<StandupsList>

  var body: some View {
    // TODO: :/ add ViewState
    WithViewStore(self.store, observe: \.standups) { (viewStore: ViewStore<IdentifiedArrayOf<Standup>, StandupsList.Action>) in
      NavigationStackStore(
        self.store.scope(state: \.$path, action: StandupsList.Action.path)
      ) {
        List {
          ForEach(viewStore.state) { standup in
            Button {
              viewStore.send(.standupTapped(id: standup.id))
            } label: {
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
        .navigationDestination(
          store: self.store.scope(state: \.$path, action: StandupsList.Action.path)
        ) { store in
          SwitchStore(store) {
            CaseLet(
              state: /StandupsList.Stack.State.detail,
              action: StandupsList.Stack.Action.detail,
              then: StandupDetailView.init(store:)
            )
            CaseLet(
              state: /StandupsList.Stack.State.meeting,
              action: StandupsList.Stack.Action.meeting,
              then: MeetingView.init(store:)
            )
            CaseLet(
              state: /StandupsList.Stack.State.record,
              action: StandupsList.Stack.Action.record,
              then: RecordMeetingView.init(store:)
            )
          }
        }
        .sheet(
          store: self.store.scope(state: \.$destination, action: StandupsList.Action.destination),
          state: /StandupsList.Destinations.State.add,
          action: StandupsList.Destinations.Action.add
        ) { store in
          NavigationStack {
            EditStandupView(store: store)
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
        .alert(
          store: self.store.scope(state: \.$destination, action: StandupsList.Action.destination),
          state: /StandupsList.Destinations.State.alert,
          action: StandupsList.Destinations.Action.alert
        )
      }
//      destinations: {
//
//      }
    }
  }
}

extension AlertState where Action == StandupsList.AlertAction {
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
      """)
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

extension URL {
  fileprivate static let standups = Self.documentsDirectory.appending(component: "standups.json")
}

struct StandupsList_Previews: PreviewProvider {
  static var previews: some View {
    StandupsListView(
      store: Store(
        initialState: StandupsList.State(),
        reducer: StandupsList()
          .dependency(\.dataManager.load) { _ in
            try JSONEncoder().encode([
              Standup.mock,
              .designMock,
              .engineeringMock,
            ])
          }
      )
    )

    StandupsListView(
      store: Store(
        initialState: StandupsList.State(),
        reducer: StandupsList()
          .dependency(\.dataManager, .mock(
            initialData: Data("!@#$% bad data ^&*()".utf8)
          ))
      )
    )
    .previewDisplayName("Load data failure")
  }
}
