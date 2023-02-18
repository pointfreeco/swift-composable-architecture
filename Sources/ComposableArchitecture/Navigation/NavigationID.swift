@_spi(Reflection) import CasePaths

extension DependencyValues {
  var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }
}

private enum NavigationIDKey: DependencyKey {
  public static let liveValue = NavigationID(path: .root)
  public static let testValue = NavigationID(path: .root)
}

public struct NavigationID: Hashable, Identifiable, Sendable {
  let path: Path

  init(path: Path) {
    self.path = path
  }

  public var id: Self {
    self
  }

  func append<Value>(_ value: Value) -> Self {
    Self(path: .destination(presenter: self, presented: Path.ComponentID(value)))
  }

  @_spi(Internals) public enum Path: Hashable, Sendable {
    case root
    indirect case destination(presenter: NavigationID, presented: ComponentID)

    @_spi(Internals) public struct ComponentID: Hashable, Sendable {
      private var objectIdentifier: ObjectIdentifier
      private var tag: UInt32?
      private var id: AnyHashableSendable?

      init<Value>(_ value: Value) {
        func id(_ identifiable: some Identifiable) -> AnyHashableSendable {
          AnyHashableSendable(identifiable.id)
        }

        self.objectIdentifier = ObjectIdentifier(Value.self)
        self.tag = enumTag(value)
        if let value = value as? any Identifiable {
          self.id = id(value)
        } else if let metadata = EnumMetadata(type(of: value)),
          metadata.associatedValueType(forTag: metadata.tag(of: value)) is any Identifiable.Type
        {
          // TODO: Extract enum payload and assign id
        }
      }
    }
  }
}

extension NavigationID: Sequence {
  public func makeIterator() -> AnyIterator<NavigationID> {
    var id: NavigationID! = self
    return AnyIterator {
      switch id?.path {
      case let .destination(presenter, _):
        defer { id = presenter }
        return id
      case .root:
        defer { id = nil }
        return id
      case .none:
        return nil
      }
    }
  }
}

private struct AnyHashableSendable: Hashable, @unchecked Sendable {
  let base: AnyHashable

  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}
