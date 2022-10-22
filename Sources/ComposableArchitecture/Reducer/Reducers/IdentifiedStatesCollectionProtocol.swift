import Foundation
import OrderedCollections

public protocol IdentifiedStates {
  associatedtype ID
  associatedtype State
  subscript(stateID stateID: ID) -> State? { get set }
}

public protocol IdentifiedStatesCollection: IdentifiedStates {
  // `RandomAccessCollection` is imposed by `ForEach` where `IDs`is used
  associatedtype IDs: RandomAccessCollection = States.Indices where IDs.Element == ID
  associatedtype States: Collection where States.Element == State

  var stateIDs: IDs { get }
  // These elements must have a 1to1 relation with IDs.
  // This is unconstrained for now, until one assesses the requirements for lazy variants.
  var states: States { get }

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
  public subscript(stateID stateID: ID) -> Element? {
    _read { yield self[id: stateID] }
    _modify { yield &self[id: stateID] }
  }

  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    areCoWEqual(lhs: self.ids, rhs: other.ids)
  }
}

extension OrderedDictionary: IdentifiedStatesCollection {
  public var stateIDs: OrderedSet<Key> { self.keys }
  public var states: OrderedDictionary<Key, Value>.Values { self.values }

  @inlinable
  public subscript(stateID stateID: Key) -> Value? {
    _read { yield self[stateID] }
    _modify { yield &self[stateID] }
  }

  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    areCoWEqual(lhs: self.keys, rhs: other.keys)
  }
}

public struct AnyIdentifiedStateCollection<IDs, States>: IdentifiedStatesCollection
where IDs: RandomAccessCollection, States: Collection {

  public typealias ID = IDs.Element
  public typealias State = States.Element

  public var stateIDs: IDs
  public var states: States
  @usableFromInline
  var get: (ID) -> State?
  @usableFromInline
  var set: (ID, State?) -> Void
  @usableFromInline
  var areDuplicateIDs: (IDs, IDs) -> Bool

  public init(
    stateIDs: () -> IDs,
    states: () -> States,
    get: @escaping (ID) -> State?,
    set: @escaping (ID, State?) -> Void,
    removeDuplicateIDs areDuplicateIDs: @escaping (IDs, IDs) -> Bool
  ) {
    self.get = get
    self.set = set
    self.stateIDs = stateIDs()
    self.states = states()
    self.areDuplicateIDs = areDuplicateIDs
  }

  public init(
    stateIDs: () -> IDs,
    states: () -> States,
    get: @escaping (ID) -> State?,
    set: @escaping (ID, State?) -> Void
  ) where IDs: Equatable {
    self.get = get
    self.set = set
    self.stateIDs = stateIDs()
    self.states = states()
    self.areDuplicateIDs = (==)
  }

  @inlinable
  public subscript(stateID stateID: ID) -> State? {
    get { self.get(stateID) }
    nonmutating set { self.set(stateID, newValue) }
  }

  public func areDuplicateIDs(other: AnyIdentifiedStateCollection<IDs, States>) -> Bool {
    self.areDuplicateIDs(self.stateIDs, other.stateIDs)
  }
}

@usableFromInline
internal func areCoWEqual<IDs: Equatable>(lhs: IDs, rhs: IDs) -> Bool {
  var lhs = lhs
  var rhs = rhs
  if memcmp(&lhs, &rhs, MemoryLayout<IDs>.size) == 0 {
    return true
  }
  return lhs == rhs
}
