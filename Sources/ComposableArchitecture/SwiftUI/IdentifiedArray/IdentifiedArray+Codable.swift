extension IdentifiedArray: Encodable where Element: Encodable {
  @inlinable
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(ContiguousArray(self._dictionary.values))
  }
}

extension IdentifiedArray: Decodable where Element: Decodable {
  @inlinable
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let elements = try container.decode(ContiguousArray<Element>.self)
    self.init(elements)
  }
}
