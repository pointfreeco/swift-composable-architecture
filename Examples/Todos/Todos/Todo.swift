import ComposableArchitecture
import SwiftUI

struct Todo: Reducer {
  @ObservableState
  struct State: Equatable, Identifiable {
    var description = ""
    let id: UUID
    var isComplete = false
  }

  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
  }
}

struct TodoView: View {
  @State var store: StoreOf<Todo>

  var body: some View {
    let _ = Self._printChanges()
    HStack {
      Button {
        self.$store.isComplete.wrappedValue.toggle()
      } label: {
        Image(systemName: self.store.isComplete ? "checkmark.square" : "square")
      }
      .buttonStyle(.plain)

      TextField("Untitled Todo", text: self.$store.description)
    }
    .foregroundColor(self.store.isComplete ? .gray : nil)
  }
}
