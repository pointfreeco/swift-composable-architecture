import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  // ...
}

extension SyncUpDetail {
  @Reducer
  struct Destination {
  }
}

struct SyncUpDetailView: View {
  // ...
}
