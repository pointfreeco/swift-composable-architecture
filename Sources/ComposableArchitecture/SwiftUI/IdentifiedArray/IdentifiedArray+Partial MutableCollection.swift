extension IdentifiedArray {
  @inlinable
  public mutating func partition(
    by belongsInSecondPartition: (Element) throws -> Bool
  ) rethrows -> Int {
    try self._dictionary.values.partition(by: belongsInSecondPartition)
  }

  @inlinable
  public mutating func reverse() {
    self._dictionary.reverse()
  }

  @inlinable
  public mutating func shuffle() {
    self._dictionary.shuffle()
  }

  @inlinable
  public mutating func shuffle<T: RandomNumberGenerator>(using generator: inout T) {
    self._dictionary.shuffle(using: &generator)
  }

  @inlinable
  public mutating func sort(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  ) rethrows {
    try self._dictionary.sort(by: { try areInIncreasingOrder($0.value, $1.value) })
  }

  @inlinable
  public mutating func swapAt(_ i: Int, _ j: Int) {
    self._dictionary.swapAt(i, j)
  }
}

extension IdentifiedArray where Element: Comparable {
  @inlinable
  public mutating func sort() {
    self.sort(by: <)
  }
}

#if canImport(SwiftUI)
import SwiftUI

extension IdentifiedArray {
  @inlinable
  public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    var removed: Self = []
    var removedBeforeDestinationCount = 0

    removed.reserveCapacity(source.count)
    for index in source.reversed() {
      removed.append(self.remove(at: index))
      if destination > index {
        removedBeforeDestinationCount += 1
      }
    }
    for element in removed {
      self.insert(element, at: destination - removedBeforeDestinationCount)
    }
  }
}
#endif
