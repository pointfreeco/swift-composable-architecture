@_spi(Reflection) import CasePaths

extension DependencyValues {
  var navigationIDPath: NavigationIDPath {
    get { self[NavigationIDPathKey.self] }
    set { self[NavigationIDPathKey.self] = newValue }
  }
}

private enum NavigationIDPathKey: DependencyKey {
  static let liveValue = NavigationIDPath()
  static let testValue = NavigationIDPath()
}

@usableFromInline
struct NavigationIDPath: Hashable, Sendable {
  fileprivate var path: [NavigationID]

  init(path: [NavigationID] = []) {
    self.path = path
  }

  var prefixes: [NavigationIDPath] {
    (0...self.path.count).map { index in
      NavigationIDPath(path: Array(self.path.dropFirst(index)))
    }
  }

  func appending(_ element: NavigationID) -> Self {
    .init(path: self.path + [element])
  }

  public var id: Self { self }
}

struct NavigationID: Hashable, @unchecked Sendable {
  private let kind: Kind
  private let identifier: AnyHashable?
  private let tag: UInt32?

  enum Kind: Hashable {
    case casePath(root: Any.Type, value: Any.Type)
    case keyPath(AnyKeyPath)

    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case let (.casePath(lhsRoot, lhsValue), .casePath(rhsRoot, rhsValue)):
        return lhsRoot == rhsRoot && lhsValue == rhsValue
      case let (.keyPath(lhs), .keyPath(rhs)):
        return lhs == rhs
      case (.casePath, _), (.keyPath, _):
        return false
      }
    }

    func hash(into hasher: inout Hasher) {
      switch self {
      case let .casePath(root: root, value: value):
        hasher.combine(0)
        hasher.combine(ObjectIdentifier(root))
        hasher.combine(ObjectIdentifier(value))
      case let .keyPath(keyPath):
        hasher.combine(1)
        hasher.combine(keyPath)
      }
    }
  }

  init<Value, Root>(
    base: Value,
    keyPath: KeyPath<Root, Value?>
  ) {
    self.kind = .keyPath(keyPath)
    self.tag = EnumMetadata(Value.self)?.tag(of: base)
    if let id = _identifiableID(base) ?? EnumMetadata.project(base).flatMap(_identifiableID) {
      self.identifier = id
    } else {
      self.identifier = nil
    }
  }

  init<Value, Root>(
    id: StackElementID,
    keyPath: KeyPath<Root, StackState<Value>>
  ) {
    self.kind = .keyPath(keyPath)
    self.tag = nil
    self.identifier = AnyHashableSendable(id)
  }

  init<Value, Root, ID: Hashable>(
    id: ID,
    keyPath: KeyPath<Root, IdentifiedArray<ID, Value>>
  ) {
    self.kind = .keyPath(keyPath)
    self.tag = nil
    self.identifier = AnyHashableSendable(id)
  }

  init<Value, Root>(
    root: Root,
    value: Value,
    casePath: AnyCasePath<Root, Value>
  ) {
    self.kind = .casePath(root: Root.self, value: Value.self)
    self.tag = EnumMetadata(Root.self)?.tag(of: root)
    if let id = _identifiableID(root) ?? _identifiableID(value) {
      self.identifier = id
    } else {
      self.identifier = nil
    }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.kind == rhs.kind
      && lhs.identifier == rhs.identifier
      && lhs.tag == rhs.tag
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.kind)
    hasher.combine(self.identifier)
    hasher.combine(self.tag)
  }
}

@_spi(Internals) public struct AnyHashableSendable: Hashable, @unchecked Sendable {
  @_spi(Internals) public let base: AnyHashable
  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}
