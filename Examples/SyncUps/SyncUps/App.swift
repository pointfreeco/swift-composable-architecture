import ComposableArchitecture
import SwiftUI

@main
struct SyncUpsApp: App {
  // NB: This is static to avoid interference with Xcode previews, which create this entry
  //     point each time they are run.
  @MainActor
  static let store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  } withDependencies: {
    if ProcessInfo.processInfo.environment["UITesting"] == "true" {
      $0.defaultFileStorage = .inMemory
    }
  }

  var body: some Scene {
    WindowGroup {
      if _XCTIsTesting {
        // NB: Don't run application in tests to avoid interference between the app and the test.
        EmptyView()
      } else {
        AppView(store: Self.store)
      }
    }
  }
}
