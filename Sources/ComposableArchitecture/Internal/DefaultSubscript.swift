final class DefaultSubscript<Value>: Hashable {
  var value: Value
  init(_ value: Value) {
    self.value = value
  }
  static func == (lhs: DefaultSubscript, rhs: DefaultSubscript) -> Bool {
    lhs === rhs
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension Optional {
  subscript(default defaultSubscript: DefaultSubscript<Wrapped>) -> Wrapped {
    get { self ?? defaultSubscript.value }
    set {
      defaultSubscript.value = newValue
      if self != nil { self = newValue }
    }
  }
}

extension RandomAccessCollection where Self: MutableCollection {
  subscript(
    position: Index,
    default defaultSubscript: DefaultSubscript<Element>
  ) -> Element {
    get { self.indices.contains(position) ? self[position] : defaultSubscript.value }
    set {
      defaultSubscript.value = newValue
      if self.indices.contains(position) { self[position] = newValue }
    }
  }
}

extension _IdentifiedCollectionProtocol {
  subscript(
    id id: ID,
    default defaultSubscript: DefaultSubscript<Element>
  ) -> Element {
    get { self[id: id] ?? defaultSubscript.value }
    set {
      defaultSubscript.value = newValue
      self[id: id] = newValue
    }
  }
}

// TODO: Move this to swift-identified-collections
import OrderedCollections
public protocol _IdentifiedCollectionProtocol: Sequence {
  associatedtype ID where ID: Hashable
  associatedtype Element
  var ids: OrderedSet<ID> { get }
  subscript(id id: ID) -> Element? { get set }
}
extension IdentifiedArray: _IdentifiedCollectionProtocol {}
