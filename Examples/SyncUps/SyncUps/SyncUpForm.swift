import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

@Reducer
struct SyncUpForm {
  struct State: Equatable, Sendable {
    @BindingState var focus: Field? = .title
    @BindingState var syncUp: SyncUp

    init(focus: Field? = .title, syncUp: SyncUp) {
      self.focus = focus
      self.syncUp = syncUp
      if self.syncUp.attendees.isEmpty {
        @Dependency(\.uuid) var uuid
        self.syncUp.attendees.append(Attendee(id: Attendee.ID(uuid())))
      }
    }

    enum Field: Hashable {
      case attendee(Attendee.ID)
      case title
    }
  }

  enum Action: BindableAction, Equatable, Sendable {
    case addAttendeeButtonTapped
    case binding(BindingAction<State>)
    case deleteAttendees(atOffsets: IndexSet)
  }

  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addAttendeeButtonTapped:
        let attendee = Attendee(id: Attendee.ID(self.uuid()))
        state.syncUp.attendees.append(attendee)
        state.focus = .attendee(attendee.id)
        return .none

      case .binding:
        return .none

      case let .deleteAttendees(atOffsets: indices):
        state.syncUp.attendees.remove(atOffsets: indices)
        if state.syncUp.attendees.isEmpty {
          state.syncUp.attendees.append(Attendee(id: Attendee.ID(self.uuid())))
        }
        guard let firstIndex = indices.first
        else { return .none }
        let index = min(firstIndex, state.syncUp.attendees.count - 1)
        state.focus = .attendee(state.syncUp.attendees[index].id)
        return .none
      }
    }
  }
}

struct SyncUpFormView: View {
  let store: StoreOf<SyncUpForm>
  @FocusState var focus: SyncUpForm.State.Field?

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          TextField("Title", text: viewStore.$syncUp.title)
            .focused(self.$focus, equals: .title)
          HStack {
            Slider(value: viewStore.$syncUp.duration.minutes, in: 5...30, step: 1) {
              Text("Length")
            }
            Spacer()
            Text(viewStore.syncUp.duration.formatted(.units()))
          }
          ThemePicker(selection: viewStore.$syncUp.theme)
        } header: {
          Text("Sync-up Info")
        }
        Section {
          ForEach(viewStore.$syncUp.attendees) { $attendee in
            TextField("Name", text: $attendee.name)
              .focused(self.$focus, equals: .attendee(attendee.id))
          }
          .onDelete { indices in
            viewStore.send(.deleteAttendees(atOffsets: indices))
          }

          Button("New attendee") {
            viewStore.send(.addAttendeeButtonTapped)
          }
        } header: {
          Text("Attendees")
        }
      }
      .bind(viewStore.$focus, to: self.$focus)
    }
  }
}

struct ThemePicker: View {
  @Binding var selection: Theme

  var body: some View {
    Picker("Theme", selection: self.$selection) {
      ForEach(Theme.allCases) { theme in
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(theme.mainColor)
          Label(theme.name, systemImage: "paintpalette")
            .padding(4)
        }
        .foregroundColor(theme.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .tag(theme)
      }
    }
  }
}

extension Duration {
  fileprivate var minutes: Double {
    get { Double(self.components.seconds / 60) }
    set { self = .seconds(newValue * 60) }
  }
}

struct EditSyncUp_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      SyncUpFormView(
        store: Store(initialState: SyncUpForm.State(syncUp: .mock)) {
          SyncUpForm()
        }
      )
    }
  }
}
