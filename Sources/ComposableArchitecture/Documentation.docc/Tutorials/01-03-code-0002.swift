import ComposableArchitecture
import SwiftUI

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      CounterView(
        store: Store(initialState: CounterFeature.State()) {
          CounterFeature()
        }
      )
    }
  }
}
