import ComposableArchitecture
import SwiftUI

struct StandupDetail: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var destination: Destination.State?
    var standup: Standup
  }
  enum Action: Equatable {
    case cancelEditButtonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case deleteMeetings(atOffsets: IndexSet)
    case destination(PresentationAction<Destination.Action>)
    case doneEditingButtonTapped
    case editButtonTapped
    case startMeetingButtonTapped

    enum Delegate: Equatable {
      case deleteStandup
      case startMeeting
    }
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.speechClient.authorizationStatus) var authorizationStatus

  struct Destination: ReducerProtocol {
    enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case edit(StandupForm.State)
    }
    enum Action: Equatable {
      case alert(Alert)
      case edit(StandupForm.Action)

      enum Alert {
        case confirmDeletion
        case continueWithoutRecording
        case openSettings
      }
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
          return .run { send in
            await send(.delegate(.deleteStandup), animation: .default)
            await self.dismiss()
          }
        case .continueWithoutRecording:
          return .send(.delegate(.startMeeting))
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

      case .startMeetingButtonTapped:
        switch self.authorizationStatus() {
        case .notDetermined, .authorized:
          return .send(.delegate(.startMeeting))

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
      Destination()
    }
  }
}

struct StandupDetailView: View {
  let store: StoreOf<StandupDetail>

  struct ViewState: Equatable {
    let standup: Standup
    init(state: StandupDetail.State) {
      self.standup = state.standup
    }
  }

  var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
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
              NavigationLink(
                state: AppFeature.Path.State.meeting(
                  MeetingReducer.State(meeting: meeting, standup: viewStore.standup)
                )
              ) {
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
      .alert(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /StandupDetail.Destination.State.alert,
        action: StandupDetail.Destination.Action.alert
      )
      .sheet(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /StandupDetail.Destination.State.edit,
        action: StandupDetail.Destination.Action.edit
      ) { store in
        NavigationStack {
          StandupFormView(store: store)
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
    }
  }
}

extension AlertState where Action == StandupDetail.Destination.Action.Alert {
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
    TextState(
      """
      You previously denied speech recognition and so your meeting meeting will not be \
      recorded. You can enable speech recognition in settings, or you can continue without \
      recording.
      """
    )
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
    TextState(
      """
      Your device does not support speech recognition and so your meeting will not be recorded.
      """
    )
  }
}

struct StandupDetail_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      StandupDetailView(
        store: Store(initialState: StandupDetail.State(standup: .mock)) {
          StandupDetail()
        }
      )
    }
  }
}
