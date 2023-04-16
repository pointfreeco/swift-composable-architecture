import ComposableArchitecture
import SwiftUI

// TODO: extra app domain to be separate from StandupsList domain so that it doesn't
//       have to depend on any other features. also move presentations to the app
//       level??

struct StandupsList: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var destination: Destination.State?
    var path: StackState<Path.State>
    var standups: IdentifiedArrayOf<Standup> = []

    init(
      destination: Destination.State? = nil,
      path: StackState<Path.State> = .init()
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
    case destination(PresentationAction<Destination.Action>)
    case dismissAddStandupButtonTapped
    case path(StackAction<Path.State, Path.Action>)
    case standupTapped(id: Standup.ID)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.dataManager) var dataManager
  @Dependency(\.date.now) var now
  @Dependency(\.uuid) var uuid

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

  struct Path: ReducerProtocol {
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

      case let .path(.element(id, .detail(.delegate(delegateAction)))):
        guard case let .some(.detail(detailState)) = state.path[id: id]
        else { return .none }

        switch delegateAction {
        case .deleteStandup:
          state.path.pop(from: id)
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

      case let .path(.element(id, .record(.delegate(delegateAction)))):
        switch delegateAction {
        case let .save(transcript: transcript):
          _ = state.path.pop(from: id)

          XCTModify(&state.path.presented, case: /Path.State.detail) { detailState in
            detailState.standup.meetings.insert(
              Meeting(
                id: Meeting.ID(self.uuid()),
                date: self.now,
                transcript: transcript
              ),
              at: 0
            )
          }

          return .none
        }

      case .path:
        return .none

      case let .standupTapped(id):
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
    .forEach(\.path, action: /Action.path) {
      Path()
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
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
        try await withTaskCancellation(id: "deadbeef", cancelInFlight: true) {  // TODO: better ID
          try await self.clock.sleep(for: .seconds(1))
          try await self.dataManager.save(JSONEncoder().encode(standups), .standups)
        }
      } catch: { _, _ in
      }
    }
  }
}

struct StandupsListView: View {
  let store: StoreOf<StandupsList>

  var body: some View {
    NavigationStackStore(
      self.store.scope(state: \.path, action: StandupsList.Action.path)
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
        .sheet(
          store: self.store.scope(state: \.$destination, action: StandupsList.Action.destination),
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
        .alert(
          store: self.store.scope(state: \.$destination, action: StandupsList.Action.destination),
          state: /StandupsList.Destination.State.alert,
          action: StandupsList.Destination.Action.alert
        )
      }
    } destination: {
      switch $0 {
      case .detail:
        CaseLet(
          state: /StandupsList.Path.State.detail,
          action: StandupsList.Path.Action.detail,
          then: StandupDetailView.init(store:)
        )
      case .meeting:
        CaseLet(
          state: /StandupsList.Path.State.meeting,
          action: StandupsList.Path.Action.meeting,
          then: MeetingView.init(store:)
        )
      case .record:
        CaseLet(
          state: /StandupsList.Path.State.record,
          action: StandupsList.Path.Action.record,
          then: RecordMeetingView.init(store:)
        )
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
          .dependency(
            \.dataManager,
            .mock(
              initialData: Data("!@#$% bad data ^&*()".utf8)
            )
          )
      )
    )
    .previewDisplayName("Load data failure")
  }
}
