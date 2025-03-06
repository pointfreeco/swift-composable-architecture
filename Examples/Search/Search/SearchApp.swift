import ComposableArchitecture
import SwiftUI

@main
struct SearchApp: App {
  
  @MainActor
  static let store = Store(initialState: Search.State()) {
    Search()
      ._printChanges()
  }
  
  var body: some Scene {
    WindowGroup {
      if isTesting {
        EmptyView()
      } else {
        SearchView(store: Self.store)
      }
    }
  }
}
