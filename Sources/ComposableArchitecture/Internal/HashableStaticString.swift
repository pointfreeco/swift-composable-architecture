public struct _HashableStaticString: RawRepresentable {
  public let rawValue: StaticString

  public init(rawValue: StaticString) {
    self.rawValue = rawValue
  }
}

extension _HashableStaticString: ExpressibleByStringLiteral {
  public init(stringLiteral value: StaticString) {
    self.init(rawValue: value)
  }
}

extension _HashableStaticString: CustomStringConvertible {
  public var description: String {
    rawValue.description
  }
}

extension _HashableStaticString: CustomDebugStringConvertible {
  public var debugDescription: String {
    rawValue.debugDescription
  }
}

extension _HashableStaticString: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.description == rhs.description
  }
}

extension _HashableStaticString: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(description)
  }
}
