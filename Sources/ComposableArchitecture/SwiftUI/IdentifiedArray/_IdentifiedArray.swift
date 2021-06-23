// - inlining
// - remove key path and rely on identifiable
// - overloads for simpler code paths
// - swift-collections-benchmark
// - eliminate overloads by using more correct subscript
// - vanilla use case?

import OrderedCollections

public struct IdentifiedArrayOf<Element> where Element: Identifiable {
  public typealias ID = Element.ID

  @usableFromInline
  var _dictionary: OrderedDictionary<ID, Element>

  @inlinable
  public init<C>(
    _ elements: C
  ) where C: RandomAccessCollection, C.Element == Element {
    self._dictionary = .init(uniqueKeysWithValues: zip(elements.map { $0.id }, elements))
  }

  @inlinable
  @inline(__always)
  public var ids: OrderedSet<ID> { self._dictionary.keys }

  @inlinable
  @inline(__always)
  public subscript(id id: ID) -> Element? {
    _read { yield self._dictionary[id] }
    _modify { yield &self._dictionary[id] }
  }

  @inlinable
  public func contains(_ element: Element) -> Bool {
    self._dictionary[element.id] != nil
  }

  @discardableResult
  @inlinable
  public mutating func remove(id: ID) -> Element? {
    self._dictionary.removeValue(forKey: id)
  }
}

extension IdentifiedArrayOf: Collection {
  @inlinable
  @inline(__always)
  public var startIndex: Int { self._dictionary.keys.startIndex }

  @inlinable
  @inline(__always)
  public var endIndex: Int { self._dictionary.keys.endIndex }

  @inlinable
  @inline(__always)
  public func index(after i: Int) -> Int { self._dictionary.keys.index(after: i) }
}

extension IdentifiedArrayOf: RandomAccessCollection {}

extension IdentifiedArrayOf: MutableCollection {
  @inlinable
  @inline(__always)
  public subscript(position: Int) -> Element {
    _read {
      yield self._dictionary[offset: position].value
    }
    _modify {
      let pair = self._dictionary[offset: position]
      var element = pair.value
      yield &element
      if element.id != pair.key {
        self._dictionary.removeValue(forKey: element.id)
        self._dictionary.updateValue(element, forKey: element.id, insertingAt: position)
      }
    }
  }
}

extension IdentifiedArrayOf: RangeReplaceableCollection {
  @inlinable
  public init() {
    self._dictionary = .init()
  }

  // MARK: correctness overloads

  @inlinable
  public mutating func replaceSubrange<C>(
    _ subrange: Range<Int>,
    with newElements: C
  ) where C: Collection, Element == C.Element {
    self._dictionary.removeSubrange(subrange)
    var index = subrange.startIndex
    for element in newElements {
      self._dictionary.updateValue(element, forKey: element.id, insertingAt: index)
      index += 1
    }
  }

  @inlinable
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    self._dictionary.reserveCapacity(minimumCapacity)
  }

  // MARK: performance overloads

  @inlinable
  public mutating func append(_ newElement: Element) {
    self._dictionary[newElement.id] = self._dictionary[newElement.id] ?? newElement
  }

  @inlinable
  @discardableResult
  public mutating func removeFirst() -> Element {
    self._dictionary.removeFirst().value
  }
}

extension IdentifiedArrayOf: ExpressibleByArrayLiteral {
  @inlinable
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

extension IdentifiedArrayOf: CustomDebugStringConvertible, CustomStringConvertible {
  public var debugDescription: String {
    self._makeCollectionDescription()
  }

  public var description: String {
    self._makeCollectionDescription()
  }

  private func _makeCollectionDescription() -> String {
    var result = "["
    var first = true
    for item in self {
      if first {
        first = false
      } else {
        result += ", "
      }
      debugPrint(item, terminator: "", to: &result)
    }
    result += "]"
    return result
  }
}

extension IdentifiedArrayOf: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(self, unlabeledChildren: Array(self), displayStyle: .collection)
  }
}

extension IdentifiedArrayOf: Decodable where Element: Decodable {
  @inlinable
  public init(from decoder: Decoder) throws {
    try self.init(ContiguousArray(from: decoder))
  }
}

extension IdentifiedArrayOf: Encodable where Element: Encodable {
  @inlinable
  public func encode(to encoder: Encoder) throws {
    try ContiguousArray(self).encode(to: encoder)
  }
}

extension IdentifiedArrayOf: Equatable where Element: Equatable {}

extension IdentifiedArrayOf: Hashable where Element: Hashable {}
