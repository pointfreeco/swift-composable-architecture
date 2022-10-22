import Foundation
import OrderedCollections


public protocol IdentifiedStates {
  associatedtype ID
  associatedtype State
  subscript(stateID stateID: ID) -> State? { get set }
}




public protocol IdentifiedStatesCollection: IdentifiedStates {
  // Strangely, it was building even with `Collection` whereas `ForEach` used
  // in `ForEachStore` expects a `RandomAccessCollection`.
  associatedtype IDs: RandomAccessCollection where IDs.Element == ID
  // A `Collection` to work nicely with `DynamicViewContent` without adding more
  // conditions.
  associatedtype States: Collection where States.Element == State
  
  // Should we use functions instead?
  var stateIDs: IDs { get }
  // These elements must have a 1to1 relation with IDs.
  // This is unconstrained for now, until one assesses the requirements for lazy variants.
  var states: States { get }
  static func areIdentifiersEqual(lhs: IDs, rhs: IDs) -> Bool
}

extension IdentifiedStatesCollection where IDs: Equatable {
  // Default for `Equatable` `IDs`.
  public static func areIdentifiersEqual(lhs: IDs, rhs: IDs) -> Bool {
    lhs == rhs
  }
}

//extension Optional: IdentifiedStates {
//  public typealias State = Wrapped
//  public typealias ID = Void
//
//  @inlinable
//  public subscript(stateID stateID: Void) -> Wrapped? {
//    _read { yield self }
//    _modify { yield &self }
//  }
//}

extension IdentifiedArray: IdentifiedStatesCollection {
  public var stateIDs: OrderedSet<ID> { self.ids }
  public var states: Self { self }

  @inlinable
  public subscript(stateID stateID: ID) -> Element? {
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
  
  @inlinable
  public subscript(stateID stateID: Key) -> Value? {
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
