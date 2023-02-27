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
  fileprivate var path: [AnyHashableSendable] = []

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
struct AnyID: Hashable, Identifiable, Sendable {
  private var objectIdentifier: ObjectIdentifier
  private var tag: UInt32?
  private var identifier: AnyHashableSendable?

  @usableFromInline
  init<Base>(_ base: Base) {
    func id<T: Identifiable>(_ identifiable: T) -> AnyHashableSendable {
      AnyHashableSendable(identifiable.id)
    }

    self.objectIdentifier = ObjectIdentifier(Base.self)
    self.tag = EnumMetadata(Base.self)?.tag(of: base)
    if let id = _id(base) {
      self.identifier = AnyHashableSendable(id)
    }
    // TODO: Extract identifiable enum payload and assign id
    // else if let metadata = EnumMetadata(type(of: base)),
    //   metadata.associatedValueType(forTag: metadata.tag(of: base)) is any Identifiable.Type
    // {
    // }
  }

  @usableFromInline
  var id: Self { self }
}

private struct AnyHashableSendable: Hashable, @unchecked Sendable {
  let base: AnyHashable

  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}
