import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  static let store = Store(initialState: Todos.State()) {
    Todos()
      ._printChanges()
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: Self.store)
    }
  }
}
