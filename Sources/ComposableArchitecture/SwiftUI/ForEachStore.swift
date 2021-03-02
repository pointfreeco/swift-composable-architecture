import SwiftUI

/// A Composable Architecture-friendly wrapper around `ForEach` that simplifies working with
/// collections of state.
///
/// `ForEachStore` loops over a store's collection with a store scoped to the domain of each
/// element. This allows you to extract and modularize an element's view and avoid concerns around
/// collection index math and parent-child store communication.
///
/// For example, a todos app may define the domain and logic associated with an individual todo:
///
///     struct TodoState: Equatable, Identifiable {
///       let id: UUID
///       var description = ""
///       var isComplete = false
///     }
///     enum TodoAction {
///       case isCompleteToggled(Bool)
///       case descriptionChanged(String)
///     }
///     struct TodoEnvironment {}
///     let todoReducer = Reducer<TodoState, TodoAction, TodoEnvironment { ... }
///
/// As well as a view with a domain-specific store:
///
///     struct TodoView: View {
///       let store: Store<TodoState, TodoAction>
///       var body: some View { ... }
///     }
///
/// For a parent domain to work with a collection of todos, it can hold onto this collection in
/// state:
///
///     struct AppState: Equatable {
///       var todos: IdentifiedArrayOf<TodoState> = []
///     }
///
/// Define a case to handle actions sent to the child domain:
///
///     enum AppAction {
///       case todo(id: TodoState.ID, action: TodoAction)
///     }
///
/// Enhance its reducer using `forEach`:
///
///     let appReducer = todoReducer.forEach(
///       state: \.todos,
///       action: /AppAction.todo(id:action:),
///       environment: { _ in TodoEnvironment() }
///     )
///
/// And finally render a list of `TodoView`s using `ForEachStore`:
///
///     ForEachStore(
///       self.store.scope(state: \.todos, AppAction.todo(id:action:))
///     ) { todoStore in
///       TodoView(store: todoStore)
///     }
public struct ForEachStore<EachState, EachAction, Data, ID, Content>: DynamicViewContent
where Data: Collection, ID: Hashable, Content: View {
  public let data: Data
  private let content: () -> Content

  /// Initializes a structure that computes views on demand from a store on an array of data and an
  /// indexed action.
  ///
  /// - Parameters:
  ///   - store: A store on an array of data and an indexed action.
  ///   - id: A key path identifying an element.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    id: KeyPath<EachState, ID>,
    content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    EachContent: View,
    Content == WithViewStore<
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >
  {
    let data = store.state.value
    self.data = data
    self.content = {
      WithViewStore(store.scope(state: { $0.map { $0[keyPath: id] } })) { viewStore in
        ForEach(Array(viewStore.state.enumerated()), id: \.element) { index, _ in
          content(
            store.scope(
              state: { index < $0.endIndex ? $0[index] : data[index] },
              action: { (index, $0) }
            )
          )
        }
      }
    }
  }

  /// Initializes a structure that computes views on demand from a store on an array of data and an
  /// indexed action.
  ///
  /// - Parameters:
  ///   - store: A store on an array of data and an indexed action.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    EachContent: View,
    Content == WithViewStore<
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >,
    EachState: Identifiable,
    EachState.ID == ID
  {
    self.init(store, id: \.id, content: content)
  }

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent: View>(
    _ store: Store<IdentifiedArray<ID, EachState>, (ID, EachAction)>,
    content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    EachContent: View,
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<[ID], (ID, EachAction), ForEach<[ID], ID, EachContent>>
  {
    let data = store.state.value
    self.data = data
    self.content = {
      WithViewStore(store.scope(state: { $0.ids })) { viewStore in
        ForEach(viewStore.state, id: \.self) { id in
          content(
            store.scope(
              state: { $0[id: id] ?? data[id: id]! },
              action: { (id, $0) }
            )
          )
        }
      }
    }
  }

  public var body: some View {
    self.content()
  }
}
