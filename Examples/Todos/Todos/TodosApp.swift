import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  
  @MainActor
  static let store = Store(initialState: Todos.State()) {
    Todos()
      ._printChange()
  }
  
  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        AppView(store: Self.store)
      }
    }
  }
}


