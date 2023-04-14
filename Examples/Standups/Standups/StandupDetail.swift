import ComposableArchitecture
import SwiftUI

struct StandupDetail: ReducerProtocol {
  struct State: Hashable {
    @PresentationState var destination: Destinations.State?
    var standup: Standup
  }
  enum Action: Equatable {
    case cancelEditButtonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case deleteMeetings(atOffsets: IndexSet)
    case destination(PresentationAction<Destinations.Action>)
    case doneEditingButtonTapped
    case editButtonTapped
    case meetingTapped(id: Meeting.ID)
    case startMeetingButtonTapped
  }
  enum AlertAction {
    case confirmDeletion
    case continueWithoutRecording
    case openSettings
  }
  enum Delegate: Equatable {
    case deleteStandup
    case goToMeeting(Meeting)
    case startMeeting
  }

  @Dependency(\.speechClient.authorizationStatus) var authorizationStatus
  @Dependency(\.openSettings) var openSettings

  struct Destinations: ReducerProtocol {
    enum State: Equatable, Hashable {
      case alert(AlertState<AlertAction>)
      case edit(StandupForm.State)
    }
    enum Action: Equatable {
      case alert(AlertAction)
      case edit(StandupForm.Action)
    }
    var body: some ReducerProtocolOf<Self> {
      Scope(state: /State.edit, action: /Action.edit) {
        StandupForm()
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
        case .continueWithoutRecording:
          return EffectTask(value: .delegate(.startMeeting))
        case .openSettings:
          return .run { _ in
            await self.openSettings()
          }
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
        state.destination = .edit(StandupForm.State(standup: state.standup))
        return .none

      case let .meetingTapped(id: id):
        guard let meeting = state.standup.meetings[id: id]
        else { return .none }
        return EffectTask(value: .delegate(.goToMeeting(meeting)))

      case .startMeetingButtonTapped:
        switch self.authorizationStatus() {
        case .notDetermined, .authorized:
          return EffectTask(value: .delegate(.startMeeting))

        case .denied:
          state.destination = .alert(.speechRecognitionDenied)
          return .none

        case .restricted:
          state.destination = .alert(.speechRecognitionRestricted)
          return .none

        @unknown default:
          return .none
        }
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
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

  static let speechRecognitionDenied = Self {
    TextState("Speech recognition denied")
  } actions: {
    ButtonState(action: .continueWithoutRecording) {
      TextState("Continue without recording")
    }
    ButtonState(action: .openSettings) {
      TextState("Open settings")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState("""
      You previously denied speech recognition and so your meeting meeting will not be \
      recorded. You can enable speech recognition in settings, or you can continue without \
      recording.
      """)
  }

  static let speechRecognitionRestricted = Self {
    TextState("Speech recognition restricted")
  } actions: {
    ButtonState(action: .continueWithoutRecording) {
      TextState("Continue without recording")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState("""
      Your device does not support speech recognition and so your meeting will not be recorded.
      """)
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
