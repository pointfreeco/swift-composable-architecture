extension IdentifiedArray: Collection {
  @inlinable
  @inline(__always)
  public var startIndex: Int { self._dictionary.keys.startIndex }

  @inlinable
  @inline(__always)
  public var endIndex: Int { self._dictionary.keys.endIndex }

  @inlinable
  @inline(__always)
  public func index(after i: Int) -> Int { self._dictionary.keys.index(after: i) }

  @inlinable
  @inline(__always)
  public subscript(position: Int) -> Element {
    _read { yield self._dictionary[offset: position].value }
  }

  @inlinable
  public func filter(
    _ isIncluded: (Element) throws -> Bool
  ) rethrows -> Self {
    try .init(_dictionary: self._dictionary.filter { try isIncluded($1) })
  }
}
