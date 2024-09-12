import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpDetail {
  @Reducer
  enum Destination {
  }
  // ...
}
extension SyncUpDetail.Destination.State: Equatable {}

struct SyncUpDetailView: View {
  // ...
}
