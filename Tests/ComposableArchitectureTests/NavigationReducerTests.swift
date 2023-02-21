import OrderedCollections
import SwiftUI
import XCTest

@propertyWrapper
public struct NavigationState<
  State
>: BidirectionalCollection, MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
  var storage: OrderedDictionary<UUID, State>

  public var startIndex: Int { self.storage.keys.startIndex }

  public var endIndex: Int { self.storage.keys.endIndex }

  public func index(after i: Int) -> Int { self.storage.keys.index(after: i) }

  public func index(before i: Int) -> Int { self.storage.keys.index(before: i) }

  public subscript(position: Int) -> State {
    _read { yield self.storage.values[position] }
    _modify { yield &self.storage.values[position] }
  }

  public init() {
    self.storage = [:]
  }

  public init(wrappedValue: Self = []) {
    self = wrappedValue
  }

  public var wrappedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }

  public var projectedValue: Path {
    _read { yield Path(state: self) }
    _modify {
      var path = Path(state: self)
      yield &path
      self = path.state
    }
  }

  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
  where State == C.Element {
    self.storage.removeSubrange(subrange)
    for element in newElements.reversed() {
      self.storage.updateValue(element, forKey: UUID(), insertingAt: subrange.startIndex)
    }
  }

  public struct Path {
    let state: NavigationState
  }
}

extension NavigationState: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: State...) {
    self.init(elements)
  }
}

public struct NavigationAction<Action> {
  enum Storage {
    case presented(UUID, Action)
    case setPath([UUID])
  }

  let storage: Storage
}

@MainActor
final class ZTests: XCTestCase {
  func testZ() {
    var xs: NavigationState<Int> = [2, 3, 1]

    print(Array(xs))

    xs.swapAt(0, 2)

    print(Array(xs))

    xs.sort()

    print(Array(xs))
  }
}
