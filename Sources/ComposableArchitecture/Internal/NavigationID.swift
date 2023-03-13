@_spi(Reflection) import CasePaths

extension DependencyValues {
  @usableFromInline
  var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }
}

private enum NavigationIDKey: DependencyKey {
  static let liveValue = NavigationID()
  static let testValue = NavigationID()
}

@usableFromInline
struct NavigationID: Hashable, Identifiable, Sendable {
  var path: [Element]

  init(path: [Element]) {
    self.path = path
  }

  public init() {
    self.path = []
  }

  var prefixes: [NavigationID] {
    (0...self.path.count).map { index in
      NavigationID(path: Array(self.path.dropFirst(index)))
    }
  }

  @usableFromInline
  func appending(_ element: Element) -> Self {
    .init(path: self.path + [element])
  }

  public var id: Self { self }
}

extension NavigationID {
  public struct Element: Hashable, Identifiable, @unchecked Sendable {
    private let kind: Kind
    private let identifier: AnyHashableSendable?
    private let tag: UInt32?

    enum Kind: Hashable, @unchecked Sendable {
      case casePath(root: Any.Type, value: Any.Type) // TODO: do tag
      case keyPath(AnyKeyPath)

      public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.casePath(lhsRoot, lhsValue), .casePath(rhsRoot, rhsValue)):
          return lhsRoot == rhsRoot && lhsValue == rhsValue
        case let (.keyPath(lhs), .keyPath(rhs)):
          return lhs == rhs
        case (.casePath, _), (.keyPath, _):
          return false
        }
      }

      public func hash(into hasher: inout Hasher) {
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

    @usableFromInline
    init<Value, Root>(
      base: Value,
      keyPath: KeyPath<Root, Value?>
    ) {
      self.kind = .keyPath(keyPath)
      self.tag = EnumMetadata(Value.self)?.tag(of: base)
      if let id = _identifiableID(base) ?? EnumMetadata.project(base).flatMap(_identifiableID) {
        self.identifier = AnyHashableSendable(id)
      } else {
        self.identifier = nil
      }
    }

    @usableFromInline
    init<Value, Root>(
      root: Root,
      value: Value,
      casePath: CasePath<Root, Value>
    ) {
      self.kind = .casePath(root: Root.self, value: Value.self)
      self.tag = EnumMetadata(Root.self)?.tag(of: root)
      if let id = _identifiableID(root) ?? _identifiableID(value) {
        self.identifier = AnyHashableSendable(id)
      } else {
        self.identifier = nil
      }
    }

    public var id: Self { self }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.kind == rhs.kind
      && lhs.identifier == rhs.identifier
      && lhs.tag == rhs.tag
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.kind)
      hasher.combine(self.identifier)
      hasher.combine(self.tag)
    }

    // TODO: better custom debug convertible stuff
  }
}

@usableFromInline
struct StableID: Hashable, Identifiable, Sendable {
  private let identifier: AnyHashableSendable?
  private let tag: UInt32?
  private let type: Any.Type

  @usableFromInline
  init<Base>(base: Base) {
    self.tag = EnumMetadata(Base.self)?.tag(of: base)
    if let id = _identifiableID(base) ?? EnumMetadata.project(base).flatMap(_identifiableID) {
      self.identifier = AnyHashableSendable(id)
    } else {
      self.identifier = nil
    }
    self.type = Base.self
  }

  public var id: Self { self }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.identifier == rhs.identifier
    && lhs.tag == rhs.tag
    && lhs.type == rhs.type
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.identifier)
    hasher.combine(self.tag)
    hasher.combine(ObjectIdentifier(self.type))
  }

  // TODO: better custom debug convertible stuff
}

@usableFromInline
struct AnyHashableSendable: Hashable, @unchecked Sendable {
  @usableFromInline
  let base: AnyHashable

  @usableFromInline
  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}
