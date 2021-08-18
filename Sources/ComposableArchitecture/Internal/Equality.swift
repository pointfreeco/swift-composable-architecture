func isEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  var lhs = lhs
  var rhs = rhs
  return memcmp(&lhs, &rhs, MemoryLayout<T>.size) == 0
    || (Box<T>.self as? AnyEquatable.Type)?.isEqual(lhs, rhs) == true
}
private protocol AnyEquatable {
  static func isEqual<T>(_ lhs: T, _ rhs: T) -> Bool
}
private enum Box<PossiblyEquatable> {}
extension Box: AnyEquatable where PossiblyEquatable: Equatable {
  static func isEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
    lhs as? PossiblyEquatable == rhs as? PossiblyEquatable
  }
}
