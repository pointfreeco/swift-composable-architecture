import Foundation
import Perception

/// A type that emits notifications to observers when underlying data changes.
///
/// Conforming to this protocol signals to other APIs that the value type supports observation.
/// However, applying the ``ObservableState`` protocol by itself to a type doesn’t add observation
/// functionality to the type. Instead, always use the ``ObservableState()`` macro when adding
/// observation support to a type.
public protocol ObservableState: Perceptible {
  var _$id: ObservableStateID { get }
  mutating func _$willModify()
}

/// A unique identifier for a observed value.
public struct ObservableStateID: Equatable, Hashable, Sendable {
  @usableFromInline
  var location: UUID {
    get { self.storage.location.value }
    set {
      if isKnownUniquelyReferenced(&self.storage) {
        self.storage.location.setValue(newValue)
      } else {
        self.storage = Storage(location: newValue, tag: self.tag)
      }
    }
  }

  @usableFromInline
  var tag: Int? {
    self.storage.tag
  }

  private var storage: Storage

  @usableFromInline
  init(location: UUID, tag: Int? = nil) {
    self.storage = Storage(location: location, tag: tag)
  }

  public init() {
    self.init(location: UUID())
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.storage === rhs.storage
      || lhs.storage.location.value == rhs.storage.location.value
      && lhs.storage.tag == rhs.storage.tag
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.location)
    hasher.combine(self.tag)
  }

  @inlinable
  public static func _$id<T>(for value: T) -> Self {
    (value as? any ObservableState)?._$id ?? ._$inert
  }

  @inlinable
  public static func _$id(for value: some ObservableState) -> Self {
    value._$id
  }

  public static let _$inert = Self()

  @inlinable
  public func _$tag(_ tag: Int?) -> Self {
    Self(location: self.location, tag: tag)
  }

  @inlinable
  public mutating func _$willModify() {
    self.location = UUID()
  }

  private final class Storage: Sendable {
    fileprivate let location: LockIsolated<UUID>
    fileprivate let tag: Int?

    init(location: UUID = UUID(), tag: Int? = nil) {
      self.location = LockIsolated(location)
      self.tag = tag
    }
  }
}

// TODO: Do we need this? check again with modify PR is merged
//public func _$isIdentityEqual<T: ObservableState>(
//  _ lhs: T, _ rhs: T
//) -> Bool {
//  return lhs._$id == rhs._$id
//}

@inlinable
public func _$isIdentityEqual<ID: Hashable, T: ObservableState>(
  _ lhs: IdentifiedArray<ID, T>, 
  _ rhs: IdentifiedArray<ID, T>
) -> Bool {
  return areOrderedSetsDuplicates(lhs.ids, rhs.ids)
}

@inlinable
public func _$isIdentityEqual<T: ObservableState>(
  _ lhs: PresentationState<T>, 
  _ rhs: PresentationState<T>
) -> Bool {
  return lhs.wrappedValue?._$id == rhs.wrappedValue?._$id
}

@inlinable
public func _$isIdentityEqual<T: ObservableState>(
  _ lhs: StackState<T>, 
  _ rhs: StackState<T>
) -> Bool {
  return areOrderedSetsDuplicates(lhs.ids, rhs.ids)
}

@inlinable
public func _$isIdentityEqual<C: Collection>(
  _ lhs: C,
  _ rhs: C
) -> Bool
where C.Element: ObservableState
{
  lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0._$id == $1._$id }
}

// NB: This is a fast path so that String is not checked as a collection.
@inlinable
public func _$isIdentityEqual(_ lhs: String, _ rhs: String) -> Bool {
  return false
}

@inlinable
public func _$isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  guard !_isPOD(T.self) else { return false }
  
  func openCollection<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
    guard C.Element.self is ObservableState.Type else {
      return false
    }

    func openIdentifiable<Element: Identifiable>(_: Element.Type) -> Bool? {
      guard
        let lhs = lhs as? IdentifiedArrayOf<Element>,
        let rhs = rhs as? IdentifiedArrayOf<Element>
      else {
        return nil
      }
      return areOrderedSetsDuplicates(lhs.ids, rhs.ids)
    }

    if
      let identifiable = C.Element.self as? any Identifiable.Type,
      let result = openIdentifiable(identifiable)
    {
      return result
    } else if let rhs = rhs as? C {
      return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy(_$isIdentityEqual)
    } else {
      return false
    }
  }

  if let lhs = lhs as? any ObservableState, let rhs = rhs as? any ObservableState {
    return lhs._$id == rhs._$id
  } else if let lhs = lhs as? any Collection {
    return openCollection(lhs, rhs)
  } else {
    return false
  }
}

@inlinable
public func _$willModify<T>(_: inout T) {}
@inlinable
public func _$willModify<T: ObservableState>(_ value: inout T) {
  value._$willModify()
}
