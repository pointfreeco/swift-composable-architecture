import ComposableArchitecture
import SwiftData
import SwiftUI

@main
@MainActor
struct SyncUpsApp: App {
  let store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  } withDependencies: {
    let schema = Schema([SyncUp.self])
    $0.modelContainer = try! ModelContainer(
      for: schema,
      configurations: [
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
      ]
    )
    if ProcessInfo.processInfo.environment["UITesting"] == "true" {
      $0.dataManager = .mock()
    }
  }

  var body: some Scene {
    WindowGroup {
      // NB: This conditional is here only to facilitate UI testing so that we can mock out certain
      //     dependencies for the duration of the test (e.g. the data manager). We do not really
      //     recommend performing UI tests in general, but we do want to demonstrate how it can be
      //     done.
      if _XCTIsTesting {
        // NB: Don't run application when testing so that it doesn't interfere with tests.
        EmptyView()
      } else {
        AppView(store: store)
      }
    }
  }
}
