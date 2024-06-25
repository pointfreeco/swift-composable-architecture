@_spi(Internals)
public struct HashableStaticString: Hashable {
  let rawValue: StaticString

  public static func == (lhs: Self, rhs: Self) -> Bool {
    "\(lhs.rawValue)" == "\(rhs.rawValue)"
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine("\(rawValue)")
  }
}
