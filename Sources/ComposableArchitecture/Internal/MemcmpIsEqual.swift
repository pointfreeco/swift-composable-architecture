import Foundation

@inlinable
func memcmpIsEqual<T: Equatable>(_ lhs: T, _ rhs: T) -> Bool {
  var lhs = lhs
  var rhs = rhs
  return memcmp(&lhs, &rhs, MemoryLayout<T>.size) == 0 || lhs == rhs
}
