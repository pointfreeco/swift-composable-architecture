import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  @Reducer
  enum Path {
    case detail(SyncUpDetail)
    case meeting(Meeting, syncUp: SyncUp)
  }
  // ...
}
