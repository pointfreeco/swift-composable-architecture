import ComposableArchitecture
import SwiftUI

@main
struct TCATestApp: App {
  @State var store = Store(initialState: CounterFeature.State()) {
    CounterFeature()
      ._printChanges()
  }

  var body: some Scene {
    WindowGroup {
      CounterView(store: self.store)
    }
  }
}
