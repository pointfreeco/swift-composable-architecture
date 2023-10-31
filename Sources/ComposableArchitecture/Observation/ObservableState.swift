import Foundation

/// A type that emits notifications to observers when underlying data changes.
public protocol ObservableState: _TCAObservable {
  var _$id: ObservableStateID { get }
}

public struct ObservableStateID: Equatable, Hashable, Sendable {
  private let uuid: UUID
  private var tag: Int?

  public init() {
    self.uuid = UUID()
  }

  public static let _$inert = Self()

  public func _$tag(_ tag: Int?) -> Self {
    var copy = self
    copy.tag = tag
    return copy
  }

  public static func _$id<T>(for value: T) -> Self {
    (value as? any ObservableState)?._$id ?? ._$inert
  }
  public static func _$id(for value: some ObservableState) -> Self {
    value._$id
  }
}

public func _isIdentityEqual<T>(_ lhs: IdentifiedArrayOf<T>, _ rhs: IdentifiedArrayOf<T>) -> Bool {
  areOrderedSetsDuplicates(lhs.ids, rhs.ids)
}

public func _isIdentityEqual<T>(_ lhs: StackState<T>, _ rhs: StackState<T>) -> Bool {
  areOrderedSetsDuplicates(lhs.ids, rhs.ids)
}

// TODO: When is this hit?
@_disfavoredOverload
public func _isIdentityEqual<C: Collection>(_ lhs: C, _ rhs: C) -> Bool
where C.Element: ObservableState {
  lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0._$id == $1._$id }
}

public func _isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  // TODO: Are these dynamic checks ever hit?
  func openCollection<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
    guard C.Element.self is ObservableState.Type else { return false }

    func openIdentifiable<Element: Identifiable>(_: Element.Type) -> Bool? {
      guard
        let lhs = lhs as? IdentifiedArrayOf<Element>,
        let rhs = rhs as? IdentifiedArrayOf<Element>
      else { return nil }
      return areOrderedSetsDuplicates(lhs.ids, rhs.ids)
    }

    if
      let identifiable = C.Element.self as? any Identifiable.Type,
      let result = openIdentifiable(identifiable)
    {
      return result
    } else if let rhs = rhs as? C {
      return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy(_isIdentityEqual)
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
