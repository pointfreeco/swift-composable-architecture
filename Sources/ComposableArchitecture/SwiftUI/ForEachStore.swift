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
/// struct Todo: ReducerProtocol {
///   struct State: Equatable, Identifiable {
///     let id: UUID
///     var description = ""
///     var isComplete = false
///   }
///
///   enum Action {
///     case isCompleteToggled(Bool)
///     case descriptionChanged(String)
///   }
///
///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> { ... }
/// }
/// ```
///
/// As well as a view with a domain-specific store:
///
/// ```swift
/// struct TodoView: View {
///   let store: StoreOf<Todo>
///   var body: some View { ... }
/// }
/// ```
///
/// For a parent domain to work with a collection of todos, it can hold onto this collection in
/// state:
///
/// ```swift
/// struct Todos: ReducerProtocol { {
///   struct State: Equatable {
///     var todos: IdentifiedArrayOf<TodoState> = []
///   }
/// ```
///
/// Define a case to handle actions sent to the child domain:
///
/// ```swift
/// enum Action {
///   case todo(id: TodoState.ID, action: TodoAction)
/// }
/// ```
///
/// Enhance its core reducer using ``ReducerProtocol/forEach(_:action:_:file:fileID:line:)``:
///
/// ```swift
/// var body: some ReducerProtocol<State, Action> {
///   Reduce { state, action in
///     ...
///   }
///   .forEach(state: \.todos, action: /Action.todo(id:action:)) {
///     Todo()
///   }
/// }
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
public struct ForEachStore<
  EachState, EachAction, Data: Collection, ID: Hashable, Content: View
>: DynamicViewContent {
  public let data: Data
  let content: Content

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
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      OrderedSet<ID>, (ID, EachAction), ForEach<OrderedSet<ID>, ID, EachContent>
    >
  {
    self.data = store.state.value
    self.content = WithViewStore(
      store,
      observe: { $0.ids },
      removeDuplicates: areOrderedSetsDuplicates
    ) { viewStore in
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

  public var body: some View {
    self.content
  }
}

private func areOrderedSetsDuplicates<ID: Hashable>(lhs: OrderedSet<ID>, rhs: OrderedSet<ID>)
  -> Bool
{
  var lhs = lhs
  var rhs = rhs
  if memcmp(&lhs, &rhs, MemoryLayout<OrderedSet<ID>>.size) == 0 {
    return true
  }
  return lhs == rhs
}
