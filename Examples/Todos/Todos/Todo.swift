import ComposableArchitecture
import Foundation
import GRDB
import SwiftUI

@ObservableState
struct Todo: Codable, Equatable, Identifiable {
  var description = ""
  var id: Int?
  var isComplete = false

  enum CodingKeys: String, CodingKey {
    case _description = "description"
    case _id = "id"
    case _isComplete = "isComplete"
  }
}

extension Todo: TableRecord, PersistableRecord, FetchableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    self.id = Int(inserted.rowID)
  }
}

@Reducer
struct TodoFeature {
  typealias State = Todo

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue

  enum CancelID {
    case debounce
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { todo, action in
      return .run { [todo] _ in
        try await withTaskCancellation(id: CancelID.debounce, cancelInFlight: true) {
          try await clock.sleep(for: .seconds(0.3))
          try await defaultDatabaseQueue.write { db in
            try todo.update(db)
          }
        }
      }
    }
  }
}

struct TodoView: View {
  @Bindable var store: StoreOf<TodoFeature>

  var body: some View {
    HStack {
      Button {
        store.isComplete.toggle()
      } label: {
        Image(systemName: store.isComplete ? "checkmark.square" : "square")
      }
      .buttonStyle(.plain)

      TextField("Untitled Todo", text: $store.description)
    }
    .foregroundColor(store.isComplete ? .gray : nil)
  }
}
