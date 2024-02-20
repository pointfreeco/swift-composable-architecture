import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  // ...
}

extension SyncUpDetail {
  @Reducer
  enum Destination {
    case alert(AlertState<Alert>)
    case edit(SyncUpForm)
    enum Alert {
      case confirmButtonTapped
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
