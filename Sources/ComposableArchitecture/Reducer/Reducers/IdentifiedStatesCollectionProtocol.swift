import Foundation
import OrderedCollections

public protocol IdentifiedStatesCollectionProtocol: StateContainer {
  typealias ID = Tag
  associatedtype IDs: RandomAccessCollection = States.Indices where IDs.Element == ID
  associatedtype States: Collection where States.Element == State

  var stateIDs: IDs { get }
  // These elements must have a 1to1 relation with IDs.
  // This is unconstrained for now, until one assesses the requirements for lazy variants.
  var states: States { get }

  func areDuplicateIDs(other: Self) -> Bool
}

extension IdentifiedStatesCollectionProtocol where IDs: Equatable {
  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    self.stateIDs == other.stateIDs
  }
}

extension IdentifiedArray: IdentifiedStatesCollectionProtocol {
  public var stateIDs: OrderedSet<ID> { self.ids }
  public var states: Self { self }

  @inlinable
  public func areDuplicateIDs(other: Self) -> Bool {
    areCoWEqual(lhs: self.ids, rhs: other.ids)
  }
}

extension OrderedDictionary: IdentifiedStatesCollectionProtocol {
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

public struct IdentifiedStateCollection<IDs, States>: IdentifiedStatesCollectionProtocol
where IDs: RandomAccessCollection, States: Collection {

  public typealias ID = IDs.Element
  public typealias State = States.Element

  public var stateIDs: IDs
  public var states: States
  @usableFromInline
  var get: (ID) -> State?
  @usableFromInline
  var areDuplicateIDs: (IDs, IDs) -> Bool

  public init(
    stateIDs: () -> IDs,
    states: () -> States,
    get: @escaping (ID) -> State?,
    removeDuplicateIDs areDuplicateIDs: @escaping (IDs, IDs) -> Bool
  ) {
    self.get = get
    self.stateIDs = stateIDs()
    self.states = states()
    self.areDuplicateIDs = areDuplicateIDs
  }

  public init(
    stateIDs: () -> IDs,
    states: () -> States,
    get: @escaping (ID) -> State?
  ) where IDs: Equatable {
    self.get = get
    self.stateIDs = stateIDs()
    self.states = states()
    self.areDuplicateIDs = (==)
  }

  public func extract(tag: ID) -> States.Element? {
    self.get(tag)
  }

  public func areDuplicateIDs(other: IdentifiedStateCollection<IDs, States>) -> Bool {
    self.areDuplicateIDs(self.stateIDs, other.stateIDs)
  }
}
