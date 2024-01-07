import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  let store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some Scene {
    WindowGroup {
      //RootView()
      FeatureView(store: store)
    }
  }
}
