import ComposableArchitecture

@Reducer
struct SyncUpForm {
  @ObservableState
  struct State {
    var syncUp: SyncUp
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onDeleteAttendees(IndexSet)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .onDeleteAttendees(indexSet):
        state.attendees.remove(atOffsets: indexSet)
        if state.attendees.isEmpty {
          state.attendees.insert(
            Attendee(id: Attendee.ID())
          )
        }
        return .none
      }
    }
  }
}
