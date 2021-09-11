import ComposableArchitecture
import Foundation
import SwiftUI

struct Todo: Equatable, Identifiable {
  @BindableState var description = ""
  let id: UUID
  var isComplete = false
}

enum TodoAction: Equatable, BindableAction {
  case binding(BindingAction<Todo>)
  case checkBoxToggled
}

struct TodoEnvironment {}

let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { todo, action, _ in
  switch action {
  case .binding:
    return .none

  case .checkBoxToggled:
    todo.isComplete.toggle()
    return .none
  }
}.binding()

struct TodoView: View {
  let store: Store<Todo, TodoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        Button(action: { viewStore.send(.checkBoxToggled) }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(PlainButtonStyle())

        TextField("Untitled Todo", text: viewStore.$description)
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}
