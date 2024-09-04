import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @Reducer(state: .equatable)
  enum Destination {
    case alert(AlertState<Alert>)
    case edit(SyncUpForm)
    @CasePathable
    enum Alert {
      case confirmButtonTapped
    }
  }
  // ...
}

struct SyncUpDetailView: View {
  // ...
}
