import ComposableArchitecture
import SwiftUI

@main
struct StandupsApp: App {
  var body: some Scene {
    WindowGroup {
      StandupsListView(
        store: Store(
          initialState: StandupsList.State(
            standups: [
              .mock,
              .designMock,
              .engineeringMock,
            ]
          ),
          reducer: StandupsList()
            ._printChanges()
        )
      )
    }
  }
}
