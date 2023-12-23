import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpForm {
  @ObservableState
  struct State {
    var focus: Field? = .title
    var syncUp: SyncUp

    enum Field: Hashable {
      case attendee(Attendee.ID)
      case title
    }
  }

  enum Action: BindableAction {
    case addAttendeeButtonTapped
    case binding(BindingAction<State>)
    case onDeleteAttendees(IndexSet)
  }

  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .addAttendeeButtonTapped:
        let attendee = Attendee(id: Attendee.ID())
        state.syncUp.attendees.append(attendee)
        state.focus = .attendee(attendee.id)
        return .none

      case .binding:
        return .none

      case let .onDeleteAttendees(indexSet):
        guard let firstDeletedIndex = indexSet.first
        else { return .none }
        let firstDeletedAttendee = state.attendees[firstDeletedIndex]

        state.attendees.remove(atOffsets: indexSet)
        if state.attendees.isEmpty {
          state.attendees.insert(
            Attendee(id: Attendee.ID())
          )
        }

        guard state.focus == .attendee(firstDeletedAttendee.id)
        else { return .none }
        let index = min(firstDeletedIndex, state.syncUp.attendees.count - 1)
        state.focus = .attendee(state.syncUp.attendees[index].id)

        return .none
      }
    }
  }
}

struct SyncUpFormView: View {
  // ...
}
