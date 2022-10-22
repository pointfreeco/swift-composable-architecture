import Foundation
import OrderedCollections

public protocol IdentifiedStatesCollection {
  // Strangely, it was building even with `Collection` whereas `ForEach` used
  // in `ForEachStore` expects a `RandomAccessCollection`.
  associatedtype IDs: RandomAccessCollection
  // A `Collection` to work nicely with `DynamicViewContent` without adding more
  // conditions.
  associatedtype States: Collection

  typealias ID = IDs.Element
  typealias State = States.Element

  // Should we use functions instead?
  var stateIDs: IDs { get }
  // These elements must have a 1to1 relation with IDs.
  // This is unconstrained for now, until one assesses the requirements for lazy variants.
  var states: States { get }

  subscript(stateID stateID: ID) -> State? { get set }
  
  /// Default implementation provided, allows to memcmp for elligible types.
  static func areIdentifiersEqual(lhs: IDs, rhs: IDs) -> Bool
}

extension IdentifiedStatesCollection where IDs: Equatable {
  // Default for `Equatable` `IDs`.
  public static func areIdentifiersEqual(lhs: IDs, rhs: IDs) -> Bool {
    lhs == rhs
  }
}

extension IdentifiedArray: IdentifiedStatesCollection {
  public var stateIDs: OrderedSet<ID> { self.ids }
  public var states: Self { self }

  public subscript(stateID stateID: ID) -> State? {
    _read { yield self[id: stateID] }
    _modify { yield &self[id: stateID] }
  }

  public static func areIdentifiersEqual(lhs: OrderedSet<ID>, rhs: OrderedSet<ID>) -> Bool {
    areCoWEqual(lhs: lhs, rhs: rhs)
  }
}

extension OrderedDictionary: IdentifiedStatesCollection {
  public var stateIDs: OrderedSet<Key> { self.keys }
  public var states: OrderedDictionary<Key, Value>.Values { self.values }
  
  public subscript(stateID stateID: ID) -> State? {
    _read { yield self[stateID] }
    _modify { yield &self[stateID] }
  }
  
  public static func areIdentifiersEqual(lhs: OrderedSet<Key>, rhs: OrderedSet<Key>) -> Bool {
    areCoWEqual(lhs: lhs, rhs: rhs)
  }
}

private func areCoWEqual<IDs: Equatable>(lhs: IDs, rhs: IDs) -> Bool {
  var lhs = lhs
  var rhs = rhs
  if memcmp(&lhs, &rhs, MemoryLayout<IDs>.size) == 0 {
    return true
  }
  return lhs == rhs
}
