import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpsList {
  @ObservableState
  struct State: Equatable {
    var syncUps: IdentifiedArrayOf<SyncUp> = []
  }
}
