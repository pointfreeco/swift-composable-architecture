import OrderedCollections
import SwiftUI

/// A protocol that describes a collection of states with stable identifiers.
///
/// The library ships with two direct adopters of this protocol: `IdentifiedArray` from our
/// [Identified Collections][swift-identified-collections] library, and `OrderedDictionary` from
/// [Swift Collections][swift-collections].
///
/// [swift-identified-collections]: http://github.com/pointfreeco/swift-identified-collections
/// [swift-collections]: http://github.com/apple/swift-collections

//public protocol _IdentifiedCollection: _TaggedContainer {
//  typealias _ID = Tag
//  typealias _Elements = Self
//  associatedtype _IDs: RandomAccessCollection where _IDs.Element == Tag
//  //  associatedtype _Elements: _TaggedContainer = Self where _Elements.Value == Value
//
//  /// A `RandomAccessCollection` of ``ID`` which is in a 1-to-1 relationship with the ``states``
//  /// collection of ``StateContainer/State``.
//  ///
//  /// - Warning: You are responsible for keeping these values in an injective relationship with
//  /// ``states``, which means that a ``StateContainer/State`` value should exist for any ``ID`` from
//  /// ``stateIDs``.
//  var _ids: _IDs { get }
//
//  /// The ``State`` values contained in this collection.
//  ///
//  /// - Warning: You are responsible for keeping ``stateIDs`` in an injective relationship with
//  /// these values, which means that a ``StateContainer/State`` value should exist for any ``ID``
//  /// from ``stateIDs``.
//  var _identifiedElements: _Elements { get }
//
//  /// Returns `true` if this collection's ``stateIDs`` is the same as `other`'s ``stateIDs``.
//  ///
//  /// A default implementation is provided when ``IDs`` is `Equatable`.
//  func areIDsDuplicates(other: Self) -> Bool
//}

extension IdentifiedArray: _IterableContainerRepresentable {
  public var iterableContainer: IterableContainer<OrderedSet<ID>, Self> {
    IterableContainer(tags: self.ids, container: self)
  }
}

extension OrderedDictionary: _IterableContainerRepresentable {
  public var iterableContainer: IterableContainer<OrderedSet<Key>, Self> {
    IterableContainer(tags: self.keys, container: self)
  }
}

public protocol _IterableContainerRepresentable: _Container {
  associatedtype Tags: RandomAccessCollection where Tags.Element == Tag
  var iterableContainer: IterableContainer<Tags, Self> { get }
}

public struct IterableContainer<
  Tags: Sequence,
  Container: _Container
>: Sequence where Tags.Element == Container.Tag {
  init(
    tags: Tags,
    container: Container
  ) {
    self.tags = tags
    self.container = container
  }
  let tags: Tags
  let container: Container
  public func makeIterator() -> Iterator {
    Iterator(tags: tags, container: container)
  }

  public struct Iterator: IteratorProtocol {
    let tags: Tags
    let container: Container
    var iterator: Tags.Iterator? = nil
    public mutating func next() -> Container.Value? {
      if self.iterator == nil {
        self.iterator = tags.makeIterator()
      }
      return self.iterator?.next().flatMap(container.extract(tag:))
    }
  }
}

extension IterableContainer {
  public init(_ container: Container, tags: (Container) -> Tags) {
    self.tags = tags(container)
    self.container = container
  }
  
  public init<Tag>(_ container: Container, tags: (Container.Element) -> Tag)
  where Container: Collection, Tags == [Tag] {
    self.tags = container.map(tags)
    self.container = container
  }
}

extension IterableContainer: Equatable where Tags: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    if let lhs = lhs.tags as? any CoWEquatable, let rhs = rhs.tags as? any CoWEquatable {
      return lhs.isCoWEqual(to: rhs)
    }
    return lhs.tags == rhs.tags
  }
}

private protocol CoWEquatable {
  func isCoWEqual(to other: any CoWEquatable) -> Bool
}

extension OrderedSet: CoWEquatable {
  fileprivate func isCoWEqual(to other: any CoWEquatable) -> Bool {
    guard var rhs = other as? Self else { return false }
    var lhs = self
    if memcmp(&lhs, &rhs, MemoryLayout<Self>.size) == 0 {
      return true
    }
    return lhs == rhs
  }
}

extension IterableContainer: Collection where Tags: Collection {
  public func index(after i: Tags.Index) -> Tags.Index { tags.index(after: i) }
  public var startIndex: Tags.Index { self.tags.startIndex }
  public var endIndex: Tags.Index { self.tags.endIndex }
  public subscript(position: Tags.Index) -> Container.Value {
    return self[self.tags[position]]
  }
  subscript(tag: Tags.Element) -> Container.Value {
    guard let value = self.container.extract(tag: tag) else {
      fatalError("Failed to extract a value for \(String(describing: tag))")
    }
    return value
  }
}

extension IterableContainer: BidirectionalCollection where Tags: BidirectionalCollection {
  public func index(before i: Tags.Index) -> Tags.Index { tags.index(before: i) }
}

extension IterableContainer: RandomAccessCollection where Tags: RandomAccessCollection {}

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
  States: _IterableContainerRepresentable, EachAction, EachContent: View
>: DynamicViewContent
where States.Tags.Element: Hashable, States.Tags: Equatable {
  public typealias EachState = States.Value
  public typealias ID = States.Tags.Element

  let store: Store<States, (ID, EachAction)>
  @ObservedObject var viewStore:
    ViewStore<IterableContainer<States.Tags, States>, (ID, EachAction)>
  let content: (ID, Store<EachState, EachAction>) -> EachContent

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init(
    _ store: Store<States, (ID, EachAction)>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store,
      observe: { $0.iterableContainer }
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
    _ store: Store<States, (ID, EachAction)>,
    @ViewBuilder content: @escaping (ID, Store<EachState, EachAction>) -> EachContent
  ) {
    self.store = store
    self.viewStore = ViewStore(
      store,
      observe: { $0.iterableContainer }
    )
    self.content = content
  }

  public var body: some View {
    ForEach(viewStore.state.tags, id: \.self) { stateID in
      let state = self.viewStore[stateID]
      let eachStore = store.scope {
        $0.extract(tag: stateID) ?? state
      } action: {
        (stateID, $0)
      }
      self.content(stateID, eachStore)
    }
  }

  public var data: States.Tags {
    viewStore.state.tags
  }
}
