import ComposableArchitecture
import GRDB
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(initialState: Todos.State()) {
          Todos()
        } withDependencies: {
          $0.defaultDatabaseQueue = try! DatabaseQueue(
            path: URL.documentsDirectory.appending(path: "db.sqlite").path
          )
        }
      )
    }
  }
}
