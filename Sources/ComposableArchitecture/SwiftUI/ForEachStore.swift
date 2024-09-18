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
/// Enhance its core reducer using
/// ``Reducer/forEach(_:action:element:fileID:filePath:line:column:)-3dw7i``:
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
@available(
  iOS, deprecated: 9999,
  message:
    "Pass 'ForEach' a store scoped to an identified array and identified action, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-ForEachStore-with-ForEach]"
)
@available(
  macOS, deprecated: 9999,
  message:
    "Pass 'ForEach' a store scoped to an identified array and identified action, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-ForEachStore-with-ForEach]"
)
@available(
  tvOS, deprecated: 9999,
  message:
    "Pass 'ForEach' a store scoped to an identified array and identified action, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-ForEachStore-with-ForEach]"
)
@available(
  watchOS, deprecated: 9999,
  message:
    "Pass 'ForEach' a store scoped to an identified array and identified action, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-ForEachStore-with-ForEach]"
)
public struct ForEachStore<
  EachState, EachAction, Data: Collection, ID: Hashable & Sendable, Content: View
>: View {
  public let data: Data
  let content: Content

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
        var element = element
        content(
          store.scope(
            id: store.id(state: \.[id: id]!, action: \.[id: id]),
            state: ToState {
              element = $0[id: id] ?? element
              return element
            },
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
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
        var element = element
        let id = element[keyPath: viewStore.state.id]
        content(
          store.scope(
            id: store.id(state: \.[id: id]!, action: \.[id: id]),
            state: ToState {
              element = $0[id: id] ?? element
              return element
            },
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

#if compiler(>=6)
  extension ForEachStore: @preconcurrency DynamicViewContent {}
#else
  extension ForEachStore: DynamicViewContent {}
#endif

extension Case {
  fileprivate subscript<ID: Hashable & Sendable, Action>(id id: ID) -> Case<Action>
  where Value == (id: ID, action: Action) {
    Case<Action>(
      embed: { (id: id, action: $0) },
      extract: { $0.id == id ? $0.action : nil }
    )
  }
}
