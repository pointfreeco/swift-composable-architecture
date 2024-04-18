import ComposableArchitecture
import OSLog
import GRDB
import SwiftUI

@main
struct SyncUpsApp: App {
  @MainActor
  static let store = Store(initialState: AppFeature.State()) {
    AppFeature()
      ._printChanges()
  } withDependencies: {
    if ProcessInfo.processInfo.environment["UITesting"] != "true" {
      let logger = Logger(subsystem: "GRDB", category: "Trace")
      var configuration = Configuration()
      configuration.prepareDatabase { db in
        db.trace { logger.debug("\($0)") }
      }
      $0.defaultDatabaseQueue = try! DatabaseQueue(
        path: URL.documentsDirectory.appending(path: "db.sqlite").path,
        configuration: configuration
      )
    } else {
      $0.defaultDatabaseQueue = try! DatabaseQueue()
    }
  }

  init() {
    if ProcessInfo.processInfo.environment["UITesting"] != "true" {
      Self.store.send(.`init`)
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
