/// A collection of three elements.
public struct Three<Element> {
  public var first: Element
  public var second: Element
  public var third: Element

  public init(_ first: Element, _ second: Element, _ third: Element) {
    self.first = first
    self.second = second
    self.third = third
  }

  public func map<T>(_ transform: (Element) -> T) -> Three<T> {
    .init(transform(self.first), transform(self.second), transform(self.third))
  }
}

extension Three: MutableCollection {
  public subscript(offset: Int) -> Element {
    _read {
      switch offset {
      case 0: yield self.first
      case 1: yield self.second
      case 2: yield self.third
      default: fatalError()
      }
    }
    _modify {
      switch offset {
      case 0: yield &self.first
      case 1: yield &self.second
      case 2: yield &self.third
      default: fatalError()
      }
    }
  }

  public var startIndex: Int { 0 }
  public var endIndex: Int { 3 }
  public func index(after i: Int) -> Int { i + 1 }
}

extension Three: RandomAccessCollection {}

extension Three: Equatable where Element: Equatable {}
extension Three: Hashable where Element: Hashable {}
extension Three: Sendable where Element: Sendable {}
