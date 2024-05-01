import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  // ...
}

extension App {
  @Reducer
  enum Path {
    case detail(SyncUpDetail)
    case meeting(Meeting, syncUp: SyncUp)
    case record(RecordMeeting)
  }
}
