import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    var syncUp: SyncUp

    // NB: This initializer is required in Xcode 15.0.1 (which CI uses at the time of writing
    //     this). We can remove when Xcode 15.1 is released and CI uses it.
    #if swift(<5.9.2)
      init(destination: Destination.State? = nil, syncUp: SyncUp) {
        self.destination = destination
        self.syncUp = syncUp
      }
    #endif
  }

  enum Action: Sendable {
    case cancelEditButtonTapped
    case delegate(Delegate)
    case deleteButtonTapped
    case deleteMeetings(atOffsets: IndexSet)
    case destination(PresentationAction<Destination.Action>)
    case doneEditingButtonTapped
    case editButtonTapped
    case startMeetingButtonTapped

    @CasePathable
    enum Delegate {
      case deleteSyncUp
      case syncUpUpdated(SyncUp)
      case startMeeting
    }
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.openSettings) var openSettings
  @Dependency(\.speechClient.authorizationStatus) var authorizationStatus

  @Reducer
  struct Destination {
    @ObservableState
    enum State: Equatable {
      case alert(AlertState<Action.Alert>)
      case edit(SyncUpForm.State)
    }

    enum Action: Sendable {
      case alert(Alert)
      case edit(SyncUpForm.Action)

      enum Alert {
        case confirmDeletion
        case continueWithoutRecording
        case openSettings
      }
    }

    var body: some ReducerOf<Self> {
      Scope(state: \.edit, action: \.edit) {
        SyncUpForm()
      }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .cancelEditButtonTapped:
        state.destination = nil
        return .none

      case .delegate:
        return .none

      case .deleteButtonTapped:
        state.destination = .alert(.deleteSyncUp)
        return .none

      case let .deleteMeetings(atOffsets: indices):
        state.syncUp.meetings.remove(atOffsets: indices)
        return .none

      case let .destination(.presented(.alert(alertAction))):
        switch alertAction {
        case .confirmDeletion:
          return .run { send in
            await send(.delegate(.deleteSyncUp), animation: .default)
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
        state.syncUp = editState.syncUp
        state.destination = nil
        return .none

      case .editButtonTapped:
        state.destination = .edit(SyncUpForm.State(syncUp: state.syncUp))
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
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
    .onChange(of: \.syncUp) { oldValue, newValue in
      Reduce { state, action in
        .send(.delegate(.syncUpUpdated(newValue)))
      }
    }
  }
}

struct SyncUpDetailView: View {
  @Bindable var store: StoreOf<SyncUpDetail>

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
          Text(store.syncUp.duration.formatted(.units()))
        }

        HStack {
          Label("Theme", systemImage: "paintpalette")
          Spacer()
          Text(store.syncUp.theme.name)
            .padding(4)
            .foregroundColor(store.syncUp.theme.accentColor)
            .background(store.syncUp.theme.mainColor)
            .cornerRadius(4)
        }
      } header: {
        Text("Sync-up Info")
      }

      if !store.syncUp.meetings.isEmpty {
        Section {
          ForEach(store.syncUp.meetings) { meeting in
            NavigationLink(
              state: AppFeature.Path.State.meeting(meeting, syncUp: store.syncUp)
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
        ForEach(store.syncUp.attendees) { attendee in
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
    .navigationTitle(store.syncUp.title)
    .toolbar {
      Button("Edit") {
        store.send(.editButtonTapped)
      }
    }
    .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
      NavigationStack {
        SyncUpFormView(store: store)
          .navigationTitle(self.store.syncUp.title)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
                self.store.send(.cancelEditButtonTapped)
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                self.store.send(.doneEditingButtonTapped)
              }
            }
          }
      }
    }
  }
}

extension AlertState where Action == SyncUpDetail.Destination.Action.Alert {
  static let deleteSyncUp = Self {
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
      You previously denied speech recognition and so your meeting will not be recorded. You can \
      enable speech recognition in settings, or you can continue without recording.
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

struct SyncUpDetail_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      SyncUpDetailView(
        store: Store(initialState: SyncUpDetail.State(syncUp: .mock)) {
          SyncUpDetail()
        }
      )
    }
  }
}
