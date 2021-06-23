import OrderedCollections

public struct IdentifiedArray<Element> where Element: Identifiable {
  public typealias ID = Element.ID

  @usableFromInline
  var _dictionary: OrderedDictionary<ID, Element>

  @inlinable
  @inline(__always)
  public var ids: OrderedSet<ID> { self._dictionary.keys }

  @usableFromInline
  init(_dictionary: OrderedDictionary<ID, Element>) {
    self._dictionary = _dictionary
  }

  @inlinable
  @inline(__always)
  public subscript(id id: ID) -> Element? {
    _read { yield self._dictionary[id] }
    _modify {
      yield &self._dictionary[id]
      precondition(self._dictionary[id].map { $0.id == id } ?? true)
    }
  }

  @inlinable
  @inline(__always)
  public func index(id: ID) -> Int? {
    self._dictionary.index(forKey: id)
  }

  @inlinable
  public func contains(_ element: Element) -> Bool {
    self._dictionary[element.id] != nil
  }

  @inlinable
  @discardableResult
  public mutating func remove(id: ID) -> Element? {
    self._dictionary.removeValue(forKey: id)
  }

  @inlinable
  @discardableResult
  public mutating func remove(_ member: Element) -> Element? {
    self._dictionary.removeValue(forKey: member.id)
  }
}
