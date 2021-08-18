func isEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  var lhs = lhs
  var rhs = rhs
  return memcmp(&lhs, &rhs, MemoryLayout<T>.size) == 0
    || (Box<T>.self as? AnyEquatable.Type)?.isEqual(lhs, rhs) == true
}

private protocol AnyEquatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
}

private enum Box<T> {}

extension Box: AnyEquatable where T: Equatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    lhs as? T == rhs as? T
  }
}
