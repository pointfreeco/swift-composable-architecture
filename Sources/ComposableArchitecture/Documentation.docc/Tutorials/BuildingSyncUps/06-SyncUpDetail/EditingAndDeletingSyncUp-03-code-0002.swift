import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  // ...
}

extension SyncUpDetail {
  @Reducer
  enum Destination {
    case alert(AlertState<Alert>)
    case edit(SyncUpForm)
    @CasePathable
    enum Alert {
      case confirmButtonTapped
    }
  }
}

struct SyncUpDetailView: View {
  // ...
}
