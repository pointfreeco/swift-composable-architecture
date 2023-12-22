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
/// @Reducer
/// struct Todo {
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
///   var body: some Reducer<State, Action> {
///     // ...
///   }
/// }
/// ```
///
/// As well as a view with a domain-specific store:
///
/// ```swift
/// struct TodoView: View {
///   let store: StoreOf<Todo>
///   var body: some View { /* ... */ }
/// }
/// ```
///
/// For a parent domain to work with a collection of todos, it can hold onto this collection in
/// state:
///
/// ```swift
/// @Reducer
/// struct Todos {
///   struct State: Equatable {
///     var todos: IdentifiedArrayOf<Todo.State> = []
///   }
///   // ...
/// }
/// ```
///
/// Define a case to handle actions sent to the child domain:
///
/// ```swift
/// enum Action {
///   case todos(IdentifiedActionOf<Todo>)
/// }
/// ```
///
/// Enhance its core reducer using ``Reducer/forEach(_:action:element:fileID:line:)-247po``:
///
/// ```swift
/// var body: some Reducer<State, Action> {
///   Reduce { state, action in
///     // ...
///   }
///   .forEach(\.todos, action: \.todos) {
///     Todo()
///   }
/// }
/// ```
///
/// And finally render a list of `TodoView`s using ``ForEachStore``:
///
/// ```swift
/// ForEachStore(
///   self.store.scope(state: \.todos, action: \.todos)
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
    _ store: Store<IdentifiedArray<ID, EachState>, IdentifiedAction<ID, EachAction>>,
    @ViewBuilder content: @escaping (_ store: Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      IdentifiedArray<ID, EachState>, IdentifiedAction<ID, EachAction>,
      ForEach<IdentifiedArray<ID, EachState>, ID, EachContent>
    >
  {
    self.data = store.withState { $0 }
    self.content = WithViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
    ) { viewStore in
      ForEach(viewStore.state, id: viewStore.state.id) { element in
        let id = element[keyPath: viewStore.state.id]
        content(
          store.scope(
            id: store.id(state: \.[id:id]!, action: \.[id:id]),
            state: ToState(\.[id:id,default:SubscriptDefault(element)]),
            action: { .element(id: id, action: $0) },
            isInvalid: { !$0.ids.contains(id) }
          )
        )
      }
    }
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  public init<EachContent>(
    _ store: Store<IdentifiedArray<ID, EachState>, (id: ID, action: EachAction)>,
    @ViewBuilder content: @escaping (_ store: Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      IdentifiedArray<ID, EachState>, (id: ID, action: EachAction),
      ForEach<IdentifiedArray<ID, EachState>, ID, EachContent>
    >
  {
    self.data = store.withState { $0 }
    self.content = WithViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
    ) { viewStore in
      ForEach(viewStore.state, id: viewStore.state.id) { element in
        let id = element[keyPath: viewStore.state.id]
        content(
          store.scope(
            id: store.id(state: \.[id:id]!, action: \.[id:id]),
            state: ToState(\.[id:id,default:SubscriptDefault(element)]),
            action: { (id, $0) },
            isInvalid: { !$0.ids.contains(id) }
          )
        )
      }
    }
  }

  public var body: some View {
    self.content
  }
}

extension IdentifiedArray {
  fileprivate subscript(id id: ID, default default: SubscriptDefault<Element>) -> Element {
    `default`.wrappedValue = self[id: id] ?? `default`.wrappedValue
    return `default`.wrappedValue
  }
}

extension Case {
  fileprivate subscript<ID: Hashable, Action>(id id: ID) -> Case<Action>
  where Value == (id: ID, action: Action) {
    Case<Action>(
      embed: { (id: id, action: $0) },
      extract: { $0.id == id ? $0.action : nil }
    )
  }
}
