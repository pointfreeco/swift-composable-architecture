import ComposableArchitecture
import SwiftUI

@main
struct TCATestApp: App {
  @State var store = Store(initialState: CounterFeature.State()) {
    CounterFeature()
  }

  var body: some Scene {
    WindowGroup {
      CounterView(store: self.store)
    }
  }
}
