import ComposableArchitecture
import Foundation
import SwiftUI

struct Todo: Equatable, Identifiable {
  @BindableState var description = ""
  let id: UUID
  var isComplete = false
}

enum TodoAction: BindableAction, Equatable {
  case checkBoxToggled
  case binding(BindingAction<Todo>)
}

struct TodoEnvironment {}

let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { todo, action, _ in
  switch action {
  case .checkBoxToggled:
    todo.isComplete.toggle()
    return .none
  case .binding:
    return .none
  }
}
.binding()

struct TodoView: View {
  let store: Store<Todo, TodoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        Button(action: { viewStore.send(.checkBoxToggled) }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(.plain)

        TextField(
          "Untitled Todo",
          text: viewStore.binding(\.$description)
        )
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}
