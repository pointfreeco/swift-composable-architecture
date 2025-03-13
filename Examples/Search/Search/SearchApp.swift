import ComposableArchitecture
import SwiftUI

@main
struct SearchApp: App {
  static let store = Store(initialState: Search.State()) {
    Search()
      ._printChanges()
  }

  var body: some Scene {
    WindowGroup {
      SearchView(store: Self.store)
    }
  }
}
