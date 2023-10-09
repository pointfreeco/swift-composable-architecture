import ComposableArchitecture
import SwiftData
import SwiftUI

@Model
class Book: Identifiable {
  var title: String
  var isCheckedOut: Bool
  init(title: String = "", isCheckedOut: Bool = false) {
    self.title = title
    self.isCheckedOut = isCheckedOut
  }
}

@Model private class Private { init() {} }
private enum ModelContainerKey: DependencyKey {
  static var liveValue: ModelContainer {
    // runtimeWarn
    return try! ModelContainer(for: Private.self, configurations: ModelConfiguration())
  }
}
extension DependencyValues {
  var modelContainer: ModelContainer {
    get { self[ModelContainerKey.self] }
    set { self[ModelContainerKey.self] = newValue }
  }
}

actor ContextActor: ModelActor {
  let modelExecutor: ModelExecutor
  let modelContainer: ModelContainer
  let context: ModelContext
  init(
    modelExecutor: ModelExecutor,
    modelContainer: ModelContainer,
    context: ModelContext) {
    self.modelExecutor = modelExecutor
    self.modelContainer = modelContainer
    self.context = context
  }
}
//extension ContextActor: TestDependencyKey {
//  static var testValue: ContextActor {
//    ContextActor(
//      modelExecutor: ModelExecutor.,
//      modelContainer: <#T##ModelContainer#>,
//      context: <#T##ModelContext#>
//    )
//  }
//}

struct ModelContextClient: Sendable {
  let context: @Sendable () -> ModelContext
  func callAsFunction() -> ModelContext { self.context() }
}
extension ModelContextClient: DependencyKey {
  static var liveValue: ModelContextClient {
    Self {
      @Dependency(\.modelContainer) var modelContainer
      return ModelContext(modelContainer)
    }
  }
}
extension DependencyValues {
  var modelContext: ModelContextClient {
    get { self[ModelContextClient.self] }
    set { self[ModelContextClient.self] = newValue }
  }
}

struct LibraryFeature: Reducer {
  struct State: Equatable {
    @BindingState var books: [Book] = []
  }
  enum Action: BindableAction {
    case addButtonTapped
    case binding(BindingAction<State>)
    case onTask
  }
  @Dependency(\.continuousClock) var clock
  @Dependency(\.modelContext) var modelContext
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        let book = Book()
        state.books.append(book)
        self.modelContext().insert(book)
        return .run { send in
          //await self.modelActor.context.insert(book)
        }
      case .binding:
        return .none
      case .onTask:
        do {
          state.books = try modelContext().fetch(FetchDescriptor<Book>())
        } catch {
        }
        return .none
      }
    }
    Reduce { _, _ in
      return .run { _ in
        try await self.clock.sleep(for: .seconds(1))
        do {
          try self.modelContext().save()
        } catch {
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
        ForEach(viewStore.$books) { $book in
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
    .task { await self.store.send(.onTask).finish() }
  }
}

#Preview {
  NavigationStack {
    LibraryView(
      store: Store(initialState: LibraryFeature.State()) {
        LibraryFeature()
      } withDependencies: {
        $0.modelContainer = try! ModelContainer(
          for: Book.self,
          configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
      }
    )
  }
}
