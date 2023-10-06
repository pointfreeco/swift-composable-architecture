import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

struct StandupForm: Reducer {
  struct State: Equatable, Sendable {
    @BindingState var focus: Field? = .title
    @BindingState var standup: Standup

    init(focus: Field? = .title, standup: Standup) {
      self.focus = focus
      self.standup = standup
      if self.standup.attendees.isEmpty {
        @Dependency(\.uuid) var uuid
        self.standup.attendees.append(Attendee(id: Attendee.ID(uuid())))
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
        state.standup.attendees.append(attendee)
        state.focus = .attendee(attendee.id)
        return .none

      case .binding:
        return .none

      case let .deleteAttendees(atOffsets: indices):
        state.standup.attendees.remove(atOffsets: indices)
        if state.standup.attendees.isEmpty {
          state.standup.attendees.append(Attendee(id: Attendee.ID(self.uuid())))
        }
        guard let firstIndex = indices.first
        else { return .none }
        let index = min(firstIndex, state.standup.attendees.count - 1)
        state.focus = .attendee(state.standup.attendees[index].id)
        return .none
      }
    }
  }
}

struct StandupFormView: View {
  let store: StoreOf<StandupForm>
  @FocusState var focus: StandupForm.State.Field?

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          TextField("Title", text: viewStore.$standup.title)
            .focused(self.$focus, equals: .title)
          HStack {
            Slider(value: viewStore.$standup.duration.minutes, in: 5...30, step: 1) {
              Text("Length")
            }
            Spacer()
            Text(viewStore.standup.duration.formatted(.units()))
          }
          ThemePicker(selection: viewStore.$standup.theme)
        } header: {
          Text("Standup Info")
        }
        Section {
          ForEach(viewStore.$standup.attendees) { $attendee in
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

struct EditStandup_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      StandupFormView(
        store: Store(initialState: StandupForm.State(standup: .mock)) {
          StandupForm()
        }
      )
    }
  }
}
