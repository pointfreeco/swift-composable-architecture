// - inlining
// - remove key path and rely on identifiable
// - overloads for simpler code paths
// - swift-collections-benchmark
// - eliminate overloads by using more correct subscript
// - vanilla use case?

public struct IdentifiedArrayOf<Element> where Element: Identifiable {
  public typealias ID = Element.ID

  @usableFromInline
  var _ids: ContiguousArray<ID>

  @usableFromInline
  var _elements: [ID: Element]

  @inlinable
  public init<C>(
    _ elements: C
  ) where C: RandomAccessCollection, C.Element == Element {
    let count = elements.count
    self._ids = .init()
    self._ids.reserveCapacity(count)
    self._elements = .init(minimumCapacity: count)
    for element in elements {
      self._ids.append(element.id)
      self._elements[element.id] = self._elements[element.id] ?? element
    }
  }

  @inlinable
  @inline(__always)
  public var ids: ContiguousArray<ID> { self._ids }

  @inlinable
  @inline(__always)
  public subscript(id id: ID) -> Element? {
    _read { yield self._elements[id] }
    _modify { yield &self._elements[id] }
  }

  @inlinable
  public func contains(_ element: Element) -> Bool {
    self._elements[element.id] != nil
  }

  @discardableResult
  @inlinable
  public mutating func remove(id: ID) -> Element? {
    self._ids.removeAll(where: { $0 == id })
    return self._elements.removeValue(forKey: id)
  }
}

extension IdentifiedArrayOf: Collection {
  @inlinable
  @inline(__always)
  public var startIndex: Int { self._ids.startIndex }

  @inlinable
  @inline(__always)
  public var endIndex: Int { self._ids.endIndex }

  @inlinable
  @inline(__always)
  public func index(after i: Int) -> Int { self._ids.index(after: i) }
}

extension IdentifiedArrayOf: RandomAccessCollection {}

extension IdentifiedArrayOf: MutableCollection {
  @inlinable
  @inline(__always)
  public subscript(position: Int) -> Element {
    _read {
      yield self._elements[self._ids[position]]!
    }
    _modify {
      let id = self._ids[position]
      var element = self._elements[id]!
      yield &element
      self._ids[position] = element.id
      self._elements[element.id] = element
    }
  }
}

extension IdentifiedArrayOf: RangeReplaceableCollection {
  @inlinable
  public init() {
    self._ids = .init()
    self._elements = .init()
  }

  // MARK: correctness overloads

  @inlinable
  public mutating func replaceSubrange<C>(
    _ subrange: Range<Int>,
    with newElements: C
  ) where C: Collection, Element == C.Element {
    let oldIds = self._ids[subrange]
    self._ids.replaceSubrange(subrange, with: newElements.map { $0.id })
    for element in newElements {
      self._elements[element.id] = self._elements[element.id] ?? element
    }
    for id in oldIds where !self._ids.contains(id) {
      self._elements.removeValue(forKey: id)
    }
  }

  @inlinable
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    self._ids.reserveCapacity(minimumCapacity)
    self._elements.reserveCapacity(minimumCapacity)
  }

  // MARK: performance overloads

  @inlinable
  public mutating func append(_ newElement: Element) {
    self._ids.append(newElement.id)
    self._elements[newElement.id] = self._elements[newElement.id] ?? newElement
  }

  @inlinable
  @discardableResult
  public mutating func removeFirst() -> Element {
    let id = self._ids.removeFirst()
    return self._ids.contains(id) ? self._elements[id]! : self._elements.removeValue(forKey: id)!
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
