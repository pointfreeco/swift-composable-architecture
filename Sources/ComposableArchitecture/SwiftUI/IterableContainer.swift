import Foundation
import OrderedCollections

public struct IterableContainer<
  Tags: Sequence,
  Container: _Container
>: Sequence where Tags.Element == Container.Tag {
  @usableFromInline
  let tags: Tags
  @usableFromInline
  let container: Container

  @usableFromInline
  init(
    tags: Tags,
    container: Container
  ) {
    self.tags = tags
    self.container = container
  }
  
  public func makeIterator() -> Iterator {
    Iterator(tags: tags, container: container)
  }

  public struct Iterator: IteratorProtocol {
    let tags: Tags
    let container: Container
    var iterator: Tags.Iterator? = nil
    public mutating func next() -> Container.Value? {
      if self.iterator == nil {
        self.iterator = tags.makeIterator()
      }
      return self.iterator?.next().flatMap { container[$0] }
    }
  }
}

extension _Container {
  @usableFromInline
  subscript(tag: Tag) -> Value {
    guard let value = self.extract(tag: tag) else {
      fatalError("Failed to extract a value for \(String(describing: tag))")
    }
    return value
  }
}

extension IterableContainer {
  /// Creates an ``IterableContainer`` from a container
  /// - Parameters:
  ///   - container: A container that serves as a repository of `States`.
  ///   - tags: A function from the container to the whole collection of ``Tags``
  public init(_ container: Container, tags: (Container) -> Tags) {
    self.tags = tags(container)
    self.container = container
  }
}

extension IterableContainer: Collection
where
  Tags: Collection,
  Tags.SubSequence.Indices == Tags.Indices
{
  public var startIndex: Tags.Index { self.tags.startIndex }
  public var endIndex: Tags.Index { self.tags.endIndex }
  public func index(after i: Tags.Index) -> Tags.Index { self.tags.index(after: i) }

  public subscript(position: Tags.Index) -> Container.Value {
    self[self.tags[position]]
  }
  
  @usableFromInline
  subscript(tag: Tags.Element) -> Container.Value {
    _read { yield self.container[tag] }
  }

  public subscript(bounds: Range<Tags.Index>) -> IterableContainerSlice<Tags, Container> {
    IterableContainerSlice(tags: self.tags[bounds], container: self.container)
  }
}

extension IterableContainer: BidirectionalCollection
where Tags: BidirectionalCollection, Tags.SubSequence.Indices == Tags.Indices {
  public func index(before i: Tags.Index) -> Tags.Index { self.tags.index(before: i) }
}

extension IterableContainer: RandomAccessCollection
where Tags: RandomAccessCollection, Tags.SubSequence.Indices == Tags.Indices {}

extension IterableContainer: Equatable where Tags: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    // TODO: Implement a 5.6 variant to open CoWEquatable
    if let lhs = lhs.tags as? any CoWEquatable, let rhs = rhs.tags as? any CoWEquatable {
      return lhs.isCoWEqual(to: rhs)
    }
    return lhs.tags == rhs.tags
  }
}

private protocol CoWEquatable {
  func isCoWEqual(to other: any CoWEquatable) -> Bool
}

extension OrderedSet: CoWEquatable {
  fileprivate func isCoWEqual(to other: any CoWEquatable) -> Bool {
    guard var rhs = other as? Self else { return false }
    var lhs = self
    if memcmp(&lhs, &rhs, MemoryLayout<Self>.size) == 0 {
      return true
    }
    return lhs == rhs
  }
}

public struct IterableContainerSlice<Tags: Collection, Container: _Container>: Collection
where Tags.Element == Container.Tag, Tags.SubSequence.Indices == Tags.Indices {
  public typealias SubSequence = Self

  @usableFromInline
  let tags: Tags.SubSequence
  @usableFromInline
  let container: Container

  @usableFromInline
  init(tags: Tags.SubSequence, container: Container) {
    self.tags = tags
    self.container = container
  }

  public var indices: Tags.Indices { tags.indices }
  public var startIndex: Tags.Index { tags.startIndex }
  public var endIndex: Tags.Index { tags.endIndex }

  public func index(after i: Tags.Index) -> Tags.Index {
    tags.index(after: i)
  }

  public subscript(position: Swift.Slice<Tags>.Index) -> Container.Value {
    get {
      let tag = self.tags[position]
      return self.container.extract(tag: tag)!
    }
  }
  public subscript(bounds: Range<Index>) -> Self {
    .init(tags: tags[bounds], container: container)
  }
}

extension IterableContainerSlice: BidirectionalCollection where Tags: BidirectionalCollection {
  public func index(before i: Tags.Index) -> Tags.Index { tags.index(before: i) }
}

extension IterableContainerSlice: RandomAccessCollection where Tags: RandomAccessCollection {}
