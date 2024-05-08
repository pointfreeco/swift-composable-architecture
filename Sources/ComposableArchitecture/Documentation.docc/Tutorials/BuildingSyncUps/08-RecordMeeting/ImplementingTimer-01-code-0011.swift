import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  // ...
}

struct AppView: View {
  // ...
}

#Preview {
  @Shared(.syncUps) var syncUps = [
    SyncUp(
      id: SyncUp.ID(),
      attendees: [
        Attendee(id: Attendee.ID(), name: "Blob"),
        Attendee(id: Attendee.ID(), name: "Blob Jr"),
        Attendee(id: Attendee.ID(), name: "Blob Sr"),
      ],
      duration: .seconds(6),
      meetings: [],
      theme: .orange,
      title: "Morning Sync"
    )
  ]
  
  return AppView(
    store: Store(
      initialState: App.State(
        syncUpsList: SyncUpsList.State()
      )
    ) {
      App()
    }
  )
}
