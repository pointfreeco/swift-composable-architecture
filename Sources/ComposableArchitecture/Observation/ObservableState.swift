import Foundation

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

public func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  func open<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
    guard
      C.Element.self is ObservableState.Type,
      let rhs = rhs as? C
    else { return false }
    return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy(isIdentityEqual)
  }

  if
    let lhs = lhs as? any ObservableState,
    let rhs = rhs as? any ObservableState
  {
    return lhs._$id == rhs._$id
  } else if let lhs = lhs as? any Collection {
    return open(lhs, rhs)
  } else {
    return false
  }
}
