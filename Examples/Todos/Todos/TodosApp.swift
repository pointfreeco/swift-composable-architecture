import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(
          initialState: AppReducer.State(),
          reducer: AppReducer()
            .debug()
        )
      )
    }
  }
}
