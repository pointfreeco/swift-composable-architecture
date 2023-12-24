import ComposableArchitecture
import SwiftUI

@main
struct TodosApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(
          initialState: Todos.State(
            todos: IdentifiedArray(
              uncheckedUniqueElements: (1...10_000).map { index in
                Todo.State(description: "\(index)", id: UUID())
              }
            )
          )
        ) {
          Todos()
            //._printChanges()
        }
      )
    }
  }
}
