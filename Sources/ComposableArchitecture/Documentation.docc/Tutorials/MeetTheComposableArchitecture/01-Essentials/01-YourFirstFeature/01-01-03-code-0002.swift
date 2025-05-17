import ComposableArchitecture
import SwiftUI

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      CounterView(
        store: StoreOf<CounterFeature>(initialState: CounterFeature.State()) {
          CounterFeature()
        }
      )
    }
  }
}
