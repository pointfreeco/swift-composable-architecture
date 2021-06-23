extension IdentifiedArray {
  @inlinable
  public init<S>(uncheckedUniqueElements elements: S)
  where S: Sequence, S.Element == Element {
    self._dictionary = .init(uncheckedUniqueKeysWithValues: elements.lazy.map { ($0.id, $0) })
  }

  @inlinable
  public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
    if S.self == Self.self {
      self = elements as! Self
      return
    }
    if S.self == SubSequence.self {
      self.init(uncheckedUniqueElements: elements)
      return
    }
    self.init()
    self._dictionary.reserveCapacity(elements.underestimatedCount)
    self.append(contentsOf: elements)
  }

  @inlinable
  public init(_ elements: Self) {
    self = elements
  }

  @inlinable
  public init(_ elements: SubSequence) {
    self.init(uncheckedUniqueElements: elements)
  }
}
