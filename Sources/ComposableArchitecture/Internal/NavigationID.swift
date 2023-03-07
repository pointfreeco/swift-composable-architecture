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
struct NavigationID: Hashable, Identifiable, Sendable, CustomDebugStringConvertible {
  var path: [AnyHashableSendable] = []

  @usableFromInline
  var id: Self { self }

  @usableFromInline
  func appending<Component>(component: Component) -> Self {
    self.appending(id: AnyID(component))
  }

  @usableFromInline
  func appending(id: AnyID) -> Self {
    var navigationID = self
    navigationID.path.append(AnyHashableSendable(id))
    return navigationID
  }

  @usableFromInline
  func appending(path: AnyKeyPath) -> Self {
    var navigationID = self
    navigationID.path.append(AnyHashableSendable(path))
    return navigationID
  }

  @usableFromInline
  var debugDescription: String {
    """
    [\(self.path.map { var s = ""; debugPrint($0.base.base, terminator: "", to: &s); return s }.joined(separator: ", "))]
    """
  }
}

extension NavigationID: Sequence {
  public func makeIterator() -> AnyIterator<NavigationID> {
    var id: NavigationID? = self
    return AnyIterator {
      guard var navigationID = id else { return nil }
      defer {
        if navigationID.path.isEmpty {
          id = nil
        } else {
          navigationID.path.removeLast()
          id = navigationID
        }
      }
      return navigationID
    }
  }
}

@usableFromInline
struct AnyID: Hashable, Identifiable, Sendable, CustomDebugStringConvertible {
  private var type: Any.Type
  private var tag: UInt32?
  private var identifier: AnyHashableSendable?

  @usableFromInline
  init<Base>(_ base: Base) {
    func id<T: Identifiable>(_ identifiable: T) -> AnyHashableSendable {
      AnyHashableSendable(identifiable.id)
    }

    self.type = Base.self
    self.tag = EnumMetadata(Base.self)?.tag(of: base)
    if let id = _id(base) ?? EnumMetadata.project(base).flatMap(_id) {
      self.identifier = AnyHashableSendable(id)
    }
  }

  @usableFromInline
  var id: Self { self }

  @usableFromInline
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.type == rhs.type && lhs.tag == rhs.tag && lhs.identifier == rhs.identifier
  }

  @usableFromInline
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self.type))
    hasher.combine(self.tag)
    hasher.combine(self.identifier)
  }

  @usableFromInline
  var debugDescription: String {
    var description = String(reflecting: self.type)
    let props = [
      "tag": self.tag.map { "\($0)" },
      "id": self.identifier.map {
        var s = ""
        debugPrint($0.base.base, terminator: "", to: &s)
        return s
      }
    ]
    .compactMapValues { $0 }
    if !props.isEmpty {
      description.append(
        "(\(props.sorted(by: { $0.key > $1.key }).map { "\($0): \($1)" }.joined(separator: ", "))"
      )
    }
    return description
  }
}

struct AnyHashableSendable: Hashable, @unchecked Sendable {
  let base: AnyHashable

  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}
