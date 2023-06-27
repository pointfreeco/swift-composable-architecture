import Foundation
import OrderedCollections

@inlinable
func areOrderedSetsDuplicates<T>(_ lhs: OrderedSet<T>, _ rhs: OrderedSet<T>) -> Bool {
  withUnsafePointer(to: lhs) { lhsPointer in
    withUnsafePointer(to: rhs) { rhsPointer in
      memcmp(lhsPointer, rhsPointer, MemoryLayout<OrderedSet<T>>.size) == 0 || lhs == rhs
    }
  }
}
