import ComposableArchitecture
import Foundation
import SwiftUI

struct Todo: Equatable, Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}

enum TodoAction: Equatable {
  case checkBoxToggled
  case textFieldChanged(String)
}

struct TodoEnvironment {}

let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { todo, action, _ in
  switch action {
  case .checkBoxToggled:
    todo.isComplete.toggle()
    return .none

  case let .textFieldChanged(description):
    todo.description = description
    return .none
  }
}

struct TodoView: View {
  @ObservedObject var viewStore: ViewStore<Todo, TodoAction>

  init(store: Store<Todo, TodoAction>) {
    self.viewStore = ViewStore(store)
  }

  var body: some View {
    let _ = Self._printChanges()
    HStack {
      Button(action: { viewStore.send(.checkBoxToggled) }) {
        Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
      }
      .buttonStyle(PlainButtonStyle())

      TextField(
        "Untitled Todo",
        text: viewStore.binding(get: \.description, send: TodoAction.textFieldChanged)
      )
    }
    .foregroundColor(viewStore.isComplete ? .gray : nil)
  }
}
