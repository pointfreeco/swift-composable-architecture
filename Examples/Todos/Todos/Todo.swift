import ComposableArchitecture
import SwiftUI

var todoViewInitCount = 0
var todoViewBodyCount = 0

struct Todo: ReducerProtocol {
  struct State: Equatable, Identifiable {
    var description = ""
    let id: UUID
    var isComplete = false
  }

  enum Action: Equatable {
    case checkBoxToggled
    case textFieldChanged(String)
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
  let store: StoreOf<Todo>

  init(store: StoreOf<Todo>) {
    let _ = instrument(&todoViewInitCount, label: "TodoView.init")
    self.store = store
  }

  var body: some View {
    let _ = instrument(&todoViewBodyCount, label: "TodoView.body")
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack {
        Button(action: { viewStore.send(.checkBoxToggled) }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(.plain)

        TextField(
          "Untitled Todo",
          text: viewStore.binding(get: \.description, send: Todo.Action.textFieldChanged)
        )
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}
