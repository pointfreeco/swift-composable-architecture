import ComposableArchitecture
import SwiftUI

struct StandupDetail: Reducer {
  @ObservableState
  struct State: Equatable {
    @ObservationStateIgnored
    @PresentationState var destination: Destination.State?
    var standup: Standup

    init(destination: Destination.State? = nil, standup: Standup) {
      self.destination = destination
      self.standup = standup
    }
  }
  enum Action: Equatable, Sendable {
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
      case standupUpdated(Standup)
      case startMeeting
    }
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.speechClient.authorizationStatus) var authorizationStatus

  struct Destination: Reducer {
    enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case edit(StandupForm.State)
    }
    enum Action: Equatable, Sendable {
      case alert(Alert)
      case edit(StandupForm.Action)

      enum Alert {
        case confirmDeletion
        case continueWithoutRecording
        case openSettings
      }
    }
    var body: some ReducerOf<Self> {
      Scope(state: /State.edit, action: /Action.edit) {
        StandupForm()
      }
    }
  }

  var body: some ReducerOf<Self> {
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
    .onChange(of: \.standup) { oldValue, newValue in
      Reduce { state, action in
        .send(.delegate(.standupUpdated(newValue)))
      }
    }
  }
}

struct StandupDetailView: View {
  @State var store: StoreOf<StandupDetail>

  var body: some View {
    List {
      Section {
        Button {
          store.send(.startMeetingButtonTapped)
        } label: {
          Label("Start Meeting", systemImage: "timer")
            .font(.headline)
            .foregroundColor(.accentColor)
        }
        HStack {
          Label("Length", systemImage: "clock")
          Spacer()
          Text(store.standup.duration.formatted(.units()))
        }

        HStack {
          Label("Theme", systemImage: "paintpalette")
          Spacer()
          Text(store.standup.theme.name)
            .padding(4)
            .foregroundColor(store.standup.theme.accentColor)
            .background(store.standup.theme.mainColor)
            .cornerRadius(4)
        }
      } header: {
        Text("Standup Info")
      }

      if !store.standup.meetings.isEmpty {
        Section {
          ForEach(store.standup.meetings) { meeting in
            NavigationLink(
              state: AppFeature.Path.State.meeting(meeting, standup: store.standup)
            ) {
              HStack {
                Image(systemName: "calendar")
                Text(meeting.date, style: .date)
                Text(meeting.date, style: .time)
              }
            }
          }
          .onDelete { indices in
            store.send(.deleteMeetings(atOffsets: indices))
          }
        } header: {
          Text("Past meetings")
        }
      }

      Section {
        ForEach(store.standup.attendees) { attendee in
          Label(attendee.name, systemImage: "person")
        }
      } header: {
        Text("Attendees")
      }

      Section {
        Button("Delete") {
          store.send(.deleteButtonTapped)
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(store.standup.title)
    .toolbar {
      Button("Edit") {
        store.send(.editButtonTapped)
      }
    }
    .alert(
      store: store.scope(state: \.$destination, action: { .destination($0) }),
      state: /StandupDetail.Destination.State.alert,
      action: StandupDetail.Destination.Action.alert
    )
    .sheet(
      store: store.scope(state: \.$destination, action: { .destination($0) }),
      state: /StandupDetail.Destination.State.edit,
      action: StandupDetail.Destination.Action.edit
    ) { editStore in
//      NavigationStack {
//        StandupFormView(store: editStore)
//          .navigationTitle(store.standup.title)
//          .toolbar {
//            ToolbarItem(placement: .cancellationAction) {
//              Button("Cancel") {
//                store.send(.cancelEditButtonTapped)
//              }
//            }
//            ToolbarItem(placement: .confirmationAction) {
//              Button("Done") {
//                store.send(.doneEditingButtonTapped)
//              }
//            }
//          }
//      }
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
