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

struct TodoReducer: _Reducer {
  func reduce(into state: inout Todo, action: TodoAction) -> Effect<TodoAction, Never> {
    switch action {
    case .checkBoxToggled:
      state.isComplete.toggle()
      return .none

    case let .textFieldChanged(description):
      state.description = description
      return .none
    }
  }
}

struct TodoView: View {
  let store: Store<Todo, TodoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
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
}
