import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  // ...
}

extension SyncUpDetail {
  @Reducer
  struct Destination {
    @ObservableState
    enum State {
      case alert(AlertState<Action.Alert>)
      case edit(SyncUpForm.State)
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
