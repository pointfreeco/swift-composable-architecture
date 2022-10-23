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
public struct GeneralizedForEachStore<
  IdentifiedStates: IdentifiedStatesCollectionProtocol, EachAction, Content: View
>: DynamicViewContent
where IdentifiedStates.ID: Hashable {
  public typealias EachState = IdentifiedStates.State
  public typealias ID = IdentifiedStates.ID

  let store: Store<IdentifiedStates, (ID, EachAction)>
  @ObservedObject var viewStore: ViewStore<IdentifiedStates, (ID, EachAction)>
  let content: (ID, Store<EachState, EachAction>) -> Content

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init(
    _ store: Store<IdentifiedStates, (ID, EachAction)>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> Content
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { $0.areDuplicateIDs(other: $1) }
    )
    self.content = { content($1) }
  }

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element and its
  ///   corresponding identifier.
  public init(
    _ store: Store<IdentifiedStates, (ID, EachAction)>,
    @ViewBuilder content: @escaping (ID, Store<EachState, EachAction>) -> Content
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store,
      observe: { $0 },
      removeDuplicates: {  $0.areDuplicateIDs(other: $1) }
    )
    self.content = content
  }

  public var body: some View {
    ForEach(viewStore.stateIDs, id: \.self) { stateID in
      // TODO: Message if `nil`?
      let state = viewStore.state.extract(tag: stateID)!
      let eachStore = store.scope {
        $0.extract(tag: stateID) ?? state
      } action: {
        (stateID, $0)
      }
      self.content(stateID, eachStore)
    }
  }

  public var data: IdentifiedStates.States {
    viewStore.states
  }
}
