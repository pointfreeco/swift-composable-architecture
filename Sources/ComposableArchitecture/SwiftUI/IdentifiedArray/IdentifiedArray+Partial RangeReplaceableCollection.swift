extension IdentifiedArray {
  @inlinable
  public init() {
    self._dictionary = .init()
  }

  @inlinable
  @discardableResult
  public mutating func remove(at index: Int) -> Element {
    self._dictionary.remove(at: index).value
  }

  @inlinable
  public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
    self._dictionary.removeAll(keepingCapacity: keepCapacity)
  }

  @inlinable
  public mutating func removeAll(
    where shouldBeRemoved: (Element) throws -> Bool
  ) rethrows {
    try self._dictionary.removeAll(where: { try shouldBeRemoved($0.value) })
  }

  @inlinable
  @discardableResult
  public mutating func removeFirst() -> Element {
    self._dictionary.removeFirst().value
  }

  @inlinable
  public mutating func removeFirst(n: Int) {
    self._dictionary.removeFirst(n)
  }

  @inlinable
  @discardableResult
  public mutating func removeLast() -> Element {
    self._dictionary.removeLast().value
  }

  @inlinable
  public mutating func removeLast(_ n: Int) {
    self._dictionary.removeLast(n)
  }

  @inlinable
  public mutating func removeSubrange(_ bounds: Range<Int>) {
    self._dictionary.removeSubrange(bounds)
  }

  @inlinable
  public mutating func removeSubrange<R>(_ bounds: R)
  where R: RangeExpression, R.Bound == Int {
    self._dictionary.removeSubrange(bounds)
  }

  @inlinable
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    self._dictionary.reserveCapacity(minimumCapacity)
  }
}

#if canImport(SwiftUI)
import SwiftUI

extension IdentifiedArray {
  @inlinable
  public mutating func remove(atOffsets offsets: IndexSet) {
    for range in offsets.rangeView.reversed() {
      self.removeSubrange(range)
    }
  }
}
#endif
