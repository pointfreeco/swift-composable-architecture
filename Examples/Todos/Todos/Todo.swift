import ComposableArchitecture
import Foundation
import SwiftUI

struct TodoState: Equatable, Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}

enum TodoAction: Equatable {
  case checkBoxToggled
  case textFieldChanged(String)
}

struct TodoEnvironment {}

let todoReducer = Reducer<TodoState, TodoAction, TodoEnvironment> { state, action, _ in
  switch action {
  case .checkBoxToggled:
    state.isComplete.toggle()
    return .none

  case let .textFieldChanged(description):
    state.description = description
    return .none
  }
}

struct TodoView: View {
  let store: Store<TodoState, TodoAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack {
        Button(action: { viewStore.send(.checkBoxToggled) }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(.plain)

        TextField(
          "Untitled Todo",
          text: viewStore.binding(get: \.description, send: TodoAction.textFieldChanged)
        )
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}
