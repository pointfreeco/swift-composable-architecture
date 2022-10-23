import Foundation
import OrderedCollections
import SwiftUI

/// A protocol that describes an collection of states with stable identifiers.
///
/// The library ships with two direct adopters of this protocol: `IdentifiedArray` from our
/// [Identified Collections][swift-identified-collections] library, and `OrderedDictionary` from
/// [Swift Collections][swift-collections].
///
/// You can also use ``IdentifiedStates`` to transform any `RandomAccessCollection` into an
/// ``IdentifiedStatesCollection``, provided you're able to 
///
/// [swift-identified-collections]: http://github.com/pointfreeco/swift-identified-collections
/// [swift-collections]: http://github.com/apple/swift-collections
public protocol IdentifiedStatesCollection: StateContainer {
  typealias ID = Tag
  associatedtype IDs: RandomAccessCollection where IDs.Element == ID
  associatedtype States: Collection where States.Element == State

  var stateIDs: IDs { get }
  // These elements must have a 1to1 relation with IDs.
  // This is unconstrained for now, until one assesses the requirements for lazy variants.
  var states: States { get }

  /// Returns `true` if this collection's identifiers are the same as `other` identifiers.
  ///
  /// A default implementation is provided when ``IDs`` is `Equatable`.
  func areDuplicateIDs(other: Self) -> Bool
}

extension IdentifiedStatesCollection where IDs: Equatable {
  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    self.stateIDs == other.stateIDs
  }
}

extension IdentifiedArray: IdentifiedStatesCollection {
  public var stateIDs: OrderedSet<ID> { self.ids }
  public var states: Self { self }

  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    areCoWEqual(lhs: self.ids, rhs: other.ids)
  }
}

extension OrderedDictionary: IdentifiedStatesCollection {
  public var stateIDs: OrderedSet<Key> { self.keys }
  public var states: OrderedDictionary<Key, Value>.Values { self.values }

  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    areCoWEqual(lhs: self.keys, rhs: other.keys)
  }
}

@usableFromInline
func areCoWEqual<IDs: Equatable>(lhs: IDs, rhs: IDs) -> Bool {
  var lhs = lhs
  var rhs = rhs
  if memcmp(&lhs, &rhs, MemoryLayout<IDs>.size) == 0 {
    return true
  }
  return lhs == rhs
}

public struct IdentifiedStates<IDs, States>: IdentifiedStatesCollection
where IDs: RandomAccessCollection, States: Collection {
  public typealias ID = IDs.Element
  public typealias State = States.Element

  public let stateIDs: IDs
  public let states: States
  @usableFromInline
  let _extract: (ID) -> State?
  @usableFromInline
  let areDuplicateIDs: (IDs, IDs) -> Bool

  @inlinable
  public func extract(tag: ID) -> States.Element? {
    self._extract(tag)
  }

  @inlinable
  public func areDuplicateIDs(other: IdentifiedStates<IDs, States>) -> Bool {
    self.areDuplicateIDs(self.stateIDs, other.stateIDs)
  }
}

extension IdentifiedStates {
//  public init(
//    stateIDs: () -> IDs,
//    states: () -> States,
//    get: @escaping (ID) -> State,
//    removeDuplicateIDs areDuplicateIDs: @escaping (IDs, IDs) -> Bool
//  ) {
//    self._extract = get
//    self.stateIDs = stateIDs()
//    self.states = states()
//    self.areDuplicateIDs = areDuplicateIDs
//  }
//
//  public init(
//    stateIDs: () -> IDs,
//    states: () -> States,
//    get: @escaping (ID) -> State
//  ) where IDs: Equatable {
//    self._extract = get
//    self.stateIDs = stateIDs()
//    self.states = states()
//    self.areDuplicateIDs = (==)
//  }
  
  public init(
    states: States,
    ids: (States) -> IDs,
    removeDuplicateIDs areDuplicateIDs: @escaping (IDs, IDs) -> Bool
  ) where IDs == States.Indices {
    self.states = states
    self.stateIDs = ids(states)
    self._extract = { states[$0] }
    self.areDuplicateIDs = areDuplicateIDs
  }
  
  public init(
    states: States,
    ids: (States) -> IDs
  ) where IDs == States.Indices, IDs: Equatable {
    self.states = states
    self.stateIDs = ids(states)
    self._extract = { states[$0] }
    self.areDuplicateIDs = (==)
  }
}

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
  StatesCollection: IdentifiedStatesCollection, EachAction, Content: View
>: DynamicViewContent
where StatesCollection.ID: Hashable {
  public typealias EachState = StatesCollection.State
  public typealias ID = StatesCollection.ID

  let store: Store<StatesCollection, (ID, EachAction)>
  @ObservedObject var viewStore: ViewStore<StatesCollection, (ID, EachAction)>
  let content: (ID, Store<EachState, EachAction>) -> Content

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init(
    _ store: Store<StatesCollection, (ID, EachAction)>,
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
    _ store: Store<StatesCollection, (ID, EachAction)>,
    @ViewBuilder content: @escaping (ID, Store<EachState, EachAction>) -> Content
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { $0.areDuplicateIDs(other: $1) }
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

  public var data: StatesCollection.States {
    viewStore.states
  }
}
