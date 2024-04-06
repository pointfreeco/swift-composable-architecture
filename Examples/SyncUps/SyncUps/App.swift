import ComposableArchitecture
import SwiftUI

@main
struct SyncUpsApp: App {
  @MainActor
  static let store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  } withDependencies: {
    if ProcessInfo.processInfo.environment["UITesting"] == "true" {
      $0.defaultFileStorage = InMemoryFileStorage()
    }
  }

  var body: some Scene {
    WindowGroup {
      if _XCTIsTesting || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        // NB: Don't run application in tests/previews to avoid interference between the app and the
        //     test/preview.
        EmptyView()
      } else {
        AppView(store: Self.store)
      }
    }
  }
}
