import ComposableArchitecture
import Foundation
import SwiftUI

struct Todo: ReducerProtocol {
  struct State: Equatable, Identifiable {
    @BindableState var description = ""
    let id: UUID
    @BindableState var isComplete = false
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
  }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()
  }
}

struct TodoView: View {
  let store: StoreOf<Todo>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack {
        Button(action: { viewStore.$isComplete.wrappedValue.toggle() }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(.plain)

        TextField("Untitled Todo", text: viewStore.$description)
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}
