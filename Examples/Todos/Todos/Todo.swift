import Foundation

struct Todo: Codable, Equatable, Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}

//import ComposableArchitecture
//import SwiftUI
//
//@Reducer
//struct Todo {
//  @ObservableState
//  struct State: Equatable, Identifiable {
//    var description = ""
//    let id: UUID
//    var isComplete = false
//  }
//
//  enum Action: BindableAction, Sendable {
//    case binding(BindingAction<State>)
//  }
//
//  var body: some Reducer<State, Action> {
//    BindingReducer()
//  }
//}
//

import SwiftUI

struct TodoView: View {
  @Binding var todo: Todo

  var body: some View {
    HStack {
      Button {
        todo.isComplete.toggle()
      } label: {
        Image(systemName: todo.isComplete ? "checkmark.square" : "square")
      }
      .buttonStyle(.plain)

      TextField("Untitled Todo", text: $todo.description)
    }
    .foregroundColor(todo.isComplete ? .gray : nil)
  }
}
