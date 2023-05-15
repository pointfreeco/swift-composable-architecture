import ComposableArchitecture
import SwiftUI

@main
struct TCATestApp: App {
  static let store = Store(initialState: CounterFeature.State()) {
    CounterFeature()
  }

  var body: some Scene {
    WindowGroup {
      CounterView(store: store)
    }
  }
}
