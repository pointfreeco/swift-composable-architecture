import ComposableArchitecture
import TestingDynamicOverlay
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    let _ = print(isTesting)
    WindowGroup {
      AppView(
        store: Store(initialState: Todos.State()) {
          Todos()
        }
      )
    }
  }
}
