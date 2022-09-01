import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(
          initialState: AppState(),
          reducer:
            appReducer
            .debug(),
          environment: AppEnvironment(
            mainQueue: .main,
            uuid: { UUID() }
          )
        )
      )
    }
  }
}
