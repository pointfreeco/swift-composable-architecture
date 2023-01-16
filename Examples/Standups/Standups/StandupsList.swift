import ComposableArchitecture
import SwiftUI

// TODO: extra app domain to be separate from StandupsList domain so that it doesn't
//       have to depend on any other features. also move presentations to the app
//       level??

struct StandupsList: ReducerProtocol {
  struct State {
    @PresentationStateOf<Destinations> var destination
    @NavigationStateOf<Stack> var path  // TODO: path? stack? navigation?
    var standups: IdentifiedArrayOf<Standup> = []
  }
  enum Action {
    case addStandupButtonTapped
    case confirmAddStandupButtonTapped
    case destination(PresentationActionOf<Destinations>)
    case dismissAddStandupButtonTapped
    case path(NavigationActionOf<Stack>)  // TODO: path? stack? navigation?
    case standupTapped(id: Standup.ID)
  }

  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

  struct Destinations: ReducerProtocol {
    enum State {
      case add(EditStandup.State)
      case alert
    }

    enum Action {
      case add(EditStandup.Action)
      case alert
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

    enum Action {
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
    // Playback any changes made to stand up in detail
    Reduce<State, Action> { state, action in
      for destination in state.$path {
        guard case let .detail(detailState) = destination.element
        else { continue }
        state.standups[id: detailState.standup.id] = detailState.standup
      }
      return .none
    }

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
          standup.attendees.append(Attendee(id: Attendee.ID(self.uuid())))
        }
        state.standups.append(standup)
        state.destination = nil
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

      case let .path(.element(id: id, .record(.delegate(delegateAction)))):
        guard case let .some(.record(recordState)) = state.$path[id: id]
        else { return .none }

        switch delegateAction {
        case .save:
          _ = state.path.popLast()
          guard var stackDestination = state.$path.last
          else { return .none }

          _ = try? (/StandupsList.Stack.State.detail).modify(&stackDestination.element) {
            $0.standup.meetings.insert(
              Meeting(
                id: Meeting.ID(self.uuid()),
                date: self.now,
                transcript: recordState.transcript
              ),
              at: 0
            )
          }
          state.$path[id: stackDestination.id] = stackDestination.element
          return .none

        case .discard:
          _ = state.path.popLast()
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
  }
}

struct StandupsListView: View {
  let store: StoreOf<StandupsList>

  var body: some View {
    NavigationStackStore(
      self.store.scope(state: \.$path, action: StandupsList.Action.path)
    ) {
      WithViewStore(self.store, observe: \.standups) { viewStore in
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
      }
    }
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
      store: Store(
        initialState: StandupsList.State(
          standups: [
            .mock,
            .designMock,
            .engineeringMock,
          ]
        ),
        reducer: StandupsList()
      )
    )
  }
}
