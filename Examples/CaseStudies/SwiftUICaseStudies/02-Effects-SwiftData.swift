import ComposableArchitecture
import SwiftData
import SwiftUI

@Model
class Book {
  var title: String
  var isCheckedOut: Bool
  init(title: String = "", isCheckedOut: Bool = false) {
    self.title = title
    self.isCheckedOut = isCheckedOut
  }
}

@Model private class Foo { init() {} }
private enum ModelContainerKey: DependencyKey {
  static var liveValue: ModelContainer {
    return try! ModelContainer(for: Foo.self, configurations: ModelConfiguration())
  }
}
extension DependencyValues {
  var modelContainer: ModelContainer {
    get { self[ModelContainerKey.self] }
    set { self[ModelContainerKey.self] = newValue }
  }
}

private enum ModelContextKey: DependencyKey {
  static var liveValue: ModelContext {
    @Dependency(\.modelContainer) var modelContainer
    return ModelContext(modelContainer)
  }
}
extension DependencyValues {
  var modelContext: ModelContext {
    get { self[ModelContextKey.self] }
    set { self[ModelContextKey.self] = newValue }
  }
}

struct LibraryFeature: Reducer {
  struct State: Equatable {
    @BindingState var books: [Book] = []
  }
  enum Action: BindableAction {
    case addButtonTapped
    case binding(BindingAction<State>)
  }
  @Dependency(\.modelContext) var modelContext
  @Dependency(\.modelContainer) var modelContainer
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        let book = Book()
        state.books.append(book)
        self.modelContext.insert(book)
        return .none
      case .binding:
        return .none
      }
    }
    Reduce { _, _ in
      return .run { _ in
        //try await Task.sleep(for: .seconds(1))
        print("Try saving")
        do {
          try await self.modelContainer.mainContext.save()
          print("Saved")
          //try self.modelContext.save()
        } catch {
          print(error)
        }
      }
      .cancellable(id: CancelID.save, cancelInFlight: true)
    }
  }

  private enum CancelID { case save }
}


struct LibraryView: View {
  let store: StoreOf<LibraryFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        let tmp = viewStore.$books
        ForEach(tmp) { $book in
          HStack {
            TextField("Title", text: $book.title)
            Spacer()
            Toggle(isOn: $book.isCheckedOut) {
              Text("Checked out?")
            }
          }
          .opacity(book.isCheckedOut ? 0.5 : 1)
        }
      }
    }
    .toolbar {
      ToolbarItem {
        Button("Add") {
          self.store.send(.addButtonTapped)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    LibraryView(
      store: Store(initialState: LibraryFeature.State()) {
        LibraryFeature()
          .dependency(\.modelContainer, try! ModelContainer(for: Book.self, configurations: .init()))
      }
    )
  }
}
