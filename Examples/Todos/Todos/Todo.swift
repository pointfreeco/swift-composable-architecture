import ComposableArchitecture
import Foundation
import SwiftUI

struct Todo: Equatable, Identifiable {
  @BindableState var description = ""
  let id: UUID
  @BindableState var isComplete = false
}

enum TodoAction: BindableAction, Equatable {
  case binding(BindingAction<Todo>)
}

struct TodoReducer: _Reducer {

  static let main = Self().binding()

  func reduce(into state: inout Todo, action: TodoAction) -> Effect<TodoAction, Never> {
    switch action {
    case .binding:
      return .none
    }
  }
}

struct TodoView: View {
  let store: Store<Todo, TodoAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        Button(action: { viewStore.$isComplete.wrappedValue.toggle() }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(PlainButtonStyle())

        TextField("Untitled Todo", text: viewStore.$description)
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}
