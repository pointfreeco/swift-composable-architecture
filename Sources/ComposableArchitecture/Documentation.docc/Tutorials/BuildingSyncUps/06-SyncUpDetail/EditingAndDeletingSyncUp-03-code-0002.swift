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

    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
