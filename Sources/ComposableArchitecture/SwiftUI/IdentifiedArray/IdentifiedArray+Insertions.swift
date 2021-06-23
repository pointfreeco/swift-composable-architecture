extension IdentifiedArray {
  @inlinable
  @inline(__always)
  @discardableResult
  public mutating func append(_ newElement: Element) -> (inserted: Bool, index: Int) {
    self.insert(newElement, at: self.endIndex)
  }

  @inlinable
  public mutating func append<S>(contentsOf newElements: S)
  where S: Sequence, S.Element == Element {
    for newElement in newElements {
      self.append(newElement)
    }
  }

  @inlinable
  @discardableResult
  public mutating func insert(_ newElement: Element, at i: Int) -> (inserted: Bool, index: Int) {
    if let existing = self._dictionary.index(forKey: newElement.id) { return (false, existing) }
    self._dictionary.updateValue(newElement, forKey: newElement.id, insertingAt: i)
    return (true, i)
  }

  @inlinable
  @discardableResult
  public mutating func update(_ element: Element, at i: Int) -> Element {
    let old = self._dictionary[offset: i].key
    precondition(
      element.id == old, "The replacement element must match the identify of the original"
    )
    return self._dictionary.updateValue(element, forKey: old)!
  }

  @inlinable
  @discardableResult
  public mutating func updateOrAppend(_ element: Element) -> Element? {
    self._dictionary.updateValue(element, forKey: element.id)
  }

  @inlinable
  @discardableResult
  public mutating func updateOrInsert(
    _ element: Element,
    at i: Int
  ) -> (originalMember: Element?, index: Int) {
    self._dictionary.updateValue(element, forKey: element.id, insertingAt: i)
  }
}
