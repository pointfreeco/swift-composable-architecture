import GRDB
import SwiftUI

struct Todo: Codable, Hashable, Identifiable {
  var description = ""
  var id: Int?
  var isComplete = false
}

extension Todo: TableRecord, PersistableRecord, FetchableRecord {
  mutating func didInsert(_ inserted: InsertionSuccess) {
    self.id = Int(inserted.rowID)
  }
}

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
