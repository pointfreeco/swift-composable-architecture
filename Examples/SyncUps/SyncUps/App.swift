import ComposableArchitecture
import SwiftData
import SwiftUI

@main
@MainActor
struct SyncUpsApp: App {
  @State var store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  } withDependencies: {
    $0.modelContainer = modelContainer
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

private let modelContainer = try! ModelContainer(
  for: SyncUp.self,
  configurations: .init()
)
