public struct IdentifiedArray<ID, Element> where ID: Hashable{
  @usableFromInline
  let id: KeyPath<Element, ID>

  @usableFromInline
  var _ids: ContiguousArray<ID>

  @usableFromInline
  var _elements: [ID: Element]

  #warning("TODO")
//  public init<S>(_ elements: S, id: KeyPath<Element, ID>) where S: Sequence, S.Element == Element {
//    self.id = id
//
//    let idsAndElements = elements.map { (id: $0[keyPath: id], element: $0) }
//    self.ids = idsAndElements.map { $0.id }
//    self.dictionary = Dictionary(idsAndElements, uniquingKeysWith: { $1 })
//  }

  @inlinable
  @inline(__always)
  public var ids: ContiguousArray<ID> { self._ids }

  @inlinable
  @inline(__always)
  public subscript(id id: ID) -> Element? {
    _read { yield self._elements[id] }
    _modify { yield &self._elements[id] }
  }

  @discardableResult
  @inlinable
  public mutating func remove(id: ID) -> Element? {
    self._ids.removeAll(where: { $0 == id })
    return self._elements.removeValue(forKey: id)
  }
}

extension IdentifiedArray: Collection {
  @inlinable
  @inline(__always)
  public var startIndex: Int { 0 }

  @inlinable
  @inline(__always)
  public var endIndex: Int { _ids.count }

  @inlinable
  @inline(__always)
  public func index(after i: Int) -> Int { i + 1 }

  @inlinable
  @inline(__always)
  public var count: Int {
    self._ids.count
  }
}

extension IdentifiedArray: RandomAccessCollection {}

extension IdentifiedArray: MutableCollection {
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
      self._ids[position] = element[keyPath: self.id]
      self._elements[element[keyPath: self.id]] = element
    }
  }

  // MARK: performance overloads

  @inlinable
  public mutating func append(_ newElement: Element) {
    self._ids.append(newElement[keyPath: self.id])
    self._elements[newElement[keyPath: self.id]] = newElement
  }
}

extension IdentifiedArray: RangeReplaceableCollection where Element: Identifiable, ID == Element.ID {
  @inlinable
  public init() {
    self.id = \.id
    self._ids = .init()
    self._elements = .init()
  }

  @inlinable
  public init<C: RandomAccessCollection>(_ elements: C) where C.Element == Element {
    self.id = \.id
    let count = elements.count
    self._ids = .init()
    self._ids.reserveCapacity(count)
    self._elements = .init(minimumCapacity: count)
    for element in elements {
      self._ids.append(element[keyPath: self.id])
      self._elements[element[keyPath: self.id]] = element
    }
  }

  // MARK: performance/correctness overloads

  @inlinable
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    self._ids.reserveCapacity(minimumCapacity)
    self._elements.reserveCapacity(minimumCapacity)
  }

  @inlinable
  public mutating func replaceSubrange<C>(
    _ subrange: Range<Int>,
    with newElements: C
  ) where C: Collection, Element == C.Element {
    for id in self._ids[subrange] {
      self._elements.removeValue(forKey: id)
    }
    self._ids.replaceSubrange(subrange, with: newElements.map { $0[keyPath: self.id] })
    for element in newElements {
      self._elements[element[keyPath: self.id]] = element
    }
  }
}

extension IdentifiedArray: ExpressibleByArrayLiteral where Element: Identifiable, ID == Element.ID {
  @inlinable
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

extension IdentifiedArray: Equatable where Element: Equatable {}

extension IdentifiedArray: Hashable where Element: Hashable {}

extension IdentifiedArray: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(self, unlabeledChildren: Array(self), displayStyle: .collection)
  }
}

extension IdentifiedArray: CustomStringConvertible {
  public var description: String {
    Array(self).description
  }
}

public typealias IdentifiedArrayOf<Element> = IdentifiedArray<Element.ID, Element> where Element: Identifiable
