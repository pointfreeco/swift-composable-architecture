import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @Reducer
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
extension SyncUpDetail.Destination.State: Equatable {}

struct SyncUpDetailView: View {
  // ...
}
