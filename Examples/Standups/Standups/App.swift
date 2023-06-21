import ComposableArchitecture
import SwiftUI

@main
struct StandupsApp: App {
  var body: some Scene {
    WindowGroup {
      // NB: This conditional is here only to facilitate UI testing so that we can mock out certain
      //     dependencies for the duration of the test (e.g. the data manager). We do not really
      //     recommend performing UI tests in general, but we do want to demonstrate how it can be
      //     done.
      if _XCTIsTesting || ProcessInfo.processInfo.environment["UITesting"] == "true" {
        UITestingView()
      } else {
        AppView(
          store: Store(initialState: AppFeature.State()) {
            AppFeature()
              ._printChanges()
          }
        )
      }
    }
  }
}

struct UITestingView: View {
  var body: some View {
    AppView(
      store: Store(initialState: AppFeature.State()) {
        AppFeature()
      } withDependencies: {
        $0.dataManager = .mock()
      }
    )
  }
}
