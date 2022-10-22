import Foundation
import OrderedCollections


public protocol IdentifiedStates {
  associatedtype ID
  associatedtype State
  subscript(stateID stateID: ID) -> State? { get set }
}

public protocol IdentifiedStatesCollection: IdentifiedStates {
  // `RandomAccessCollection` is imposed by `ForEach` where `IDs`is used
  associatedtype IDs: RandomAccessCollection where IDs.Element == ID
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

// Backport deprecated variants for the time being.
extension Array: IdentifiedStatesCollection {
  public var stateIDs: Indices { self.indices }
  public var states: Self { self }

  @inlinable
  public subscript(stateID stateID: Index) -> Element? {
    _read { yield self[stateID] }
    _modify {
      var element: Element? = self[stateID]
      yield &element
      guard let element = element else { fatalError() }
      self[stateID] = element
    }
  }
}

extension Dictionary: IdentifiedStatesCollection {
  // `Keys` is not `RandomAccessCollection`, so we bake an array.
  public var stateIDs: [Key] { Array(self.keys) }
  public var states: Values { self.values }
  
  @inlinable
  public subscript(stateID stateID: Key) -> Value? {
    _read { yield self[stateID] }
    _modify { yield &self[stateID] }
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
