import ComposableArchitecture
import SwiftUI

@main
struct MyApp: App {
  static let store = Store(initialState: CounterFeature.State()) {
    CounterFeature()
  }
  
  var body: some Scene {
    WindowGroup {
      CounterView(store: MyApp.store)
    }
  }
}
