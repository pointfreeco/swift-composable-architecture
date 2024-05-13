import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpForm {
  @ObservableState
  struct State: Equatable {
    var syncUp: SyncUp
  }

  enum Action: BindableAction {
    case addAttendeeButtonTapped
    case binding(BindingAction<State>)
    case onDeleteAttendees(IndexSet)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .addAttendeeButtonTapped:
        state.syncUp.attendees.append(
          Attendee(id: Attendee.ID())
        )
        return .none

      case .binding:
        return .none

      case let .onDeleteAttendees(indices):
        state.syncUp.attendees.remove(atOffsets: indices)
        if state.syncUp.attendees.isEmpty {
          state.syncUp.attendees.append(
            Attendee(id: Attendee.ID())
          )
        }
        return .none
      }
    }
  }
}

struct SyncUpFormView: View {
  // ...
}
