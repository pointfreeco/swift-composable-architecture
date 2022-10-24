import Foundation

extension DependencyValues {
//  @usableFromInline
  @inlinable
  public var navigationID: NavigationID {
    get { self[NavigationID.self] }
    set { self[NavigationID.self] = newValue }
  }
}

// TODO: Fix sendability of (`AnyHashable`)
// TODO: generalize? ReducerID?
public struct NavigationID: @unchecked Sendable {
  public var current: AnyHashable?
  public var next: @Sendable () -> AnyHashable
}

extension NavigationID: DependencyKey {
  public static var liveValue: Self {
    let id = UUIDGenerator { UUID() }
    return Self { id() }
  }

  public static var testValue: Self {
    let id = incrementingInteger()
    return Self { id() }
  }
}

// TODO: make Sendable-safe
func incrementingInteger() -> () -> Int {
  var count = 0
  return {
    defer { count += 1 }
    return count
  }
}
