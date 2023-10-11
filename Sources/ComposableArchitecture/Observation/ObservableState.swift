import Foundation
import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public protocol ObservableState: Observable {
  var _$id: ObservableStateID { get }
}

//@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct ObservableStateID: Equatable, Hashable, Sendable {
  private let uuid: UUID

  public init() {
    self.uuid = UUID()
  }
}

@available(iOS 17, *)
public func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  if
    let lhs = lhs as? any ObservableState,
    let rhs = rhs as? any ObservableState
  {
    return lhs._$id == rhs._$id
  }
  func open<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
    guard let rhs = rhs as? C, C.Element.self is ObservableState.Type else { return false }
    return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy(isIdentityEqual)
  }
  if let lhs = lhs as? any Collection {
    return open(lhs, rhs)
  }
  return false
}
