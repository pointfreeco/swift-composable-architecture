import OrderedCollections
import SwiftUI

/// A Composable Architecture-friendly wrapper around `ForEach` that simplifies working with
/// collections of state.
///
/// ``ForEachStore`` loops over a store's collection with a store scoped to the domain of each
/// element. This allows you to extract and modularize an element's view and avoid concerns around
/// collection index math and parent-child store communication.
///
/// For example, a todos app may define the domain and logic associated with an individual todo:
///
/// ```swift
/// struct TodoState: Equatable, Identifiable {
///   let id: UUID
///   var description = ""
///   var isComplete = false
/// }
/// enum TodoAction {
///   case isCompleteToggled(Bool)
///   case descriptionChanged(String)
/// }
/// struct TodoEnvironment {}
/// let todoReducer = Reducer<TodoState, TodoAction, TodoEnvironment { ... }
/// ```
///
/// As well as a view with a domain-specific store:
///
/// ```swift
/// struct TodoView: View {
///   let store: Store<TodoState, TodoAction>
///   var body: some View { ... }
/// }
/// ```
///
/// For a parent domain to work with a collection of todos, it can hold onto this collection in
/// state:
///
/// ```swift
/// struct AppState: Equatable {
///   var todos: IdentifiedArrayOf<TodoState> = []
/// }
/// ```
///
/// Define a case to handle actions sent to the child domain:
///
/// ```swift
/// enum AppAction {
///   case todo(id: TodoState.ID, action: TodoAction)
/// }
/// ```
///
/// Enhance its reducer using ``Reducer/forEach(state:action:environment:file:line:)-gvte``:
///
/// ```swift
/// let appReducer = todoReducer.forEach(
///   state: \.todos,
///   action: /AppAction.todo(id:action:),
///   environment: { _ in TodoEnvironment() }
/// )
/// ```
///
/// And finally render a list of `TodoView`s using ``ForEachStore``:
///
/// ```swift
/// ForEachStore(
///   self.store.scope(state: \.todos, AppAction.todo(id:action:))
/// ) { todoStore in
///   TodoView(store: todoStore)
/// }
/// ```
///
public struct ForEachStore<EachState, EachAction, Data, ID, Content>: DynamicViewContent
where Data: Collection, ID: Hashable, Content: View {
  public let data: Data
  let content: () -> Content

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent>(
    _ store: Store<IdentifiedArray<ID, EachState>, (ID, EachAction)>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    EachContent: View,
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      OrderedSet<ID>, (ID, EachAction), ForEach<OrderedSet<ID>, ID, EachContent>
    >
  {
    self.data = store.state.value
    self.content = {
      WithViewStore(store.scope(state: { $0.ids })) { viewStore in
        ForEach(viewStore.state, id: \.self) { id -> EachContent in
          // NB: We cache elements here to avoid a potential crash where SwiftUI may re-evaluate
          //     views for elements no longer in the collection.
          //
          // Feedback filed: https://gist.github.com/stephencelis/cdf85ae8dab437adc998fb0204ed9a6b
          var element = store.state.value[id: id]!
          return content(
            store.scope(
              state: {
                element = $0[id: id] ?? element
                return element
              },
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
