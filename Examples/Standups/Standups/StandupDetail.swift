import ComposableArchitecture
import SwiftUI

struct StandupDetail: ReducerProtocol {
  struct State: Hashable {
    @PresentationStateOf<Destinations> var destination
    var standup: Standup
  }
  enum Action {
    case cancelEditButtonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case deleteMeetings(atOffsets: IndexSet)
    case destination(PresentationActionOf<Destinations>)
    case doneEditingButtonTapped
    case editButtonTapped
    case meetingTapped(id: Meeting.ID)
    case startMeetingButtonTapped
  }
  enum AlertAction {
    case confirmDeletion
  }
  enum Delegate {
    case deleteStandup
    case goToMeeting(Meeting)
    case startMeeting
  }

  struct Destinations: ReducerProtocol {
    enum State: Equatable, Hashable {
      case alert(AlertState<AlertAction>)
      case edit(EditStandup.State)
    }
    enum Action {
      case alert(AlertAction)
      case edit(EditStandup.Action)
    }
    var body: some ReducerProtocolOf<Self> {
      Scope(state: /State.edit, action: /Action.edit) {
        EditStandup()
      }
    }
  }

  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .cancelEditButtonTapped:
        state.destination = nil
        return .none

      case .delegate:
        return .none

      case .deleteButtonTapped:
        state.destination = .alert(.deleteStandup)
        return .none

      case let .deleteMeetings(atOffsets: indices):
        state.standup.meetings.remove(atOffsets: indices)
        return .none

      case let .destination(.presented(.alert(alertAction))):
        switch alertAction {
        case .confirmDeletion:
          return EffectTask(value: .delegate(.deleteStandup)).animation()
        }

      case .destination:
        return .none

      case .doneEditingButtonTapped:
        guard case let .some(.edit(editState)) = state.destination
        else { return .none }
        state.standup = editState.standup
        state.destination = nil
        return .none

      case .editButtonTapped:
        state.destination = .edit(EditStandup.State(standup: state.standup))
        return .none

      case let .meetingTapped(id: id):
        guard let meeting = state.standup.meetings[id: id]
        else { return .none }
        return EffectTask(value: .delegate(.goToMeeting(meeting)))

      case .startMeetingButtonTapped:
        return EffectTask(value: .delegate(.startMeeting))
      }
    }
    .presentationDestination(\.$destination, action: /Action.destination) {
      Destinations()
    }
  }
}

struct StandupDetailView: View {
  let store: StoreOf<StandupDetail>
  
  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { (viewStore: ViewStoreOf<StandupDetail>) in
      List {
        Section {
          Button {
            viewStore.send(.startMeetingButtonTapped)
          } label: {
            Label("Start Meeting", systemImage: "timer")
              .font(.headline)
              .foregroundColor(.accentColor)
          }
          HStack {
            Label("Length", systemImage: "clock")
            Spacer()
            Text(viewStore.standup.duration.formatted(.units()))
          }

          HStack {
            Label("Theme", systemImage: "paintpalette")
            Spacer()
            Text(viewStore.standup.theme.name)
              .padding(4)
              .foregroundColor(viewStore.standup.theme.accentColor)
              .background(viewStore.standup.theme.mainColor)
              .cornerRadius(4)
          }
        } header: {
          Text("Standup Info")
        }

        if !viewStore.standup.meetings.isEmpty {
          Section {
            ForEach(viewStore.standup.meetings) { meeting in
              Button {
                viewStore.send(.meetingTapped(id: meeting.id))
              } label: {
                HStack {
                  Image(systemName: "calendar")
                  Text(meeting.date, style: .date)
                  Text(meeting.date, style: .time)
                }
              }
            }
            .onDelete { indices in
              viewStore.send(.deleteMeetings(atOffsets: indices))
            }
          } header: {
            Text("Past meetings")
          }
        }

        Section {
          ForEach(viewStore.standup.attendees) { attendee in
            Label(attendee.name, systemImage: "person")
          }
        } header: {
          Text("Attendees")
        }

        Section {
          Button("Delete") {
            viewStore.send(.deleteButtonTapped)
          }
          .foregroundColor(.red)
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle(viewStore.standup.title)
      .toolbar {
        Button("Edit") {
          viewStore.send(.editButtonTapped)
        }
      }
      .sheet(
        store: self.store.scope(state: \.$destination, action: StandupDetail.Action.destination),
        state: /StandupDetail.Destinations.State.edit,
        action: StandupDetail.Destinations.Action.edit
      ) { store in
        NavigationStack {
          EditStandupView(store: store)
            .navigationTitle(viewStore.standup.title)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                  viewStore.send(.cancelEditButtonTapped)
                }
              }
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                  viewStore.send(.doneEditingButtonTapped)
                }
              }
            }

        }
      }
      .alert(
        store: self.store.scope(state: \.$destination, action: StandupDetail.Action.destination),
        state: /StandupDetail.Destinations.State.alert,
        action: StandupDetail.Destinations.Action.alert
      )
    }
  }
}

extension AlertState where Action == StandupDetail.AlertAction {
  static let deleteStandup = Self {
    TextState("Delete?")
  } actions: {
    ButtonState(role: .destructive, action: .confirmDeletion) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("Nevermind")
    }
  } message: {
    TextState("Are you sure you want to delete this meeting?")
  }
}

struct StandupDetail_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      StandupDetailView(
        store: Store(
          initialState: StandupDetail.State(standup: .mock),
          reducer: StandupDetail()
        )
      )
    }
  }
}
