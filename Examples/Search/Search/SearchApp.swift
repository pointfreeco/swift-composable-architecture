import ComposableArchitecture
import SwiftUI

@main
struct SearchApp: App {
  var body: some Scene {
    WindowGroup {
      SearchView(
        store: Store(
          initialState: .init(),
          reducer: SearchReducer()
            .debug()
        )
      )
    }
  }
}
