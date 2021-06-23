import OrderedCollections

public struct _IdentifiedArray<Element> where Element: Identifiable {
  @usableFromInline
  var _dictionary: OrderedDictionary<Element.ID, Element>

  // for ForEachStore
  @inlinable
  @inline(__always)
  public var ids: OrderedSet<Element.ID> { self._dictionary.keys }

  // for pullback
  @inlinable
  @inline(__always)
  public subscript(id id: Element.ID) -> Element? {
    _read { yield self._dictionary[id] }
    _modify {
      yield &self._dictionary[id]
      precondition(self._dictionary[id].map { $0.id == id } ?? true)
    }
  }

  @inlinable
  @discardableResult
  public mutating func insert(_ newElement: Element, at i: Int) -> (inserted: Bool, index: Int) {
    if let existing = self._dictionary.index(forKey: newElement.id) { return (false, existing) }
    self._dictionary.updateValue(newElement, forKey: newElement.id, insertingAt: i)
    return (true, i)
  }
}

extension _IdentifiedArray: RandomAccessCollection {
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
}
