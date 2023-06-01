import Foundation

extension DependencyValues {
  @_spi(Internals) public var stackElementID: StackElementIDGenerator {
    get { self[StackElementIDGenerator.self] }
    set { self[StackElementIDGenerator.self] = newValue }
  }
}

@_spi(Internals) public struct StackElementIDGenerator: DependencyKey, Sendable {
  public let next: @Sendable () -> StackElementID
  public let peek: @Sendable () -> StackElementID

  func callAsFunction() -> StackElementID {
    self.next()
  }

  public static var liveValue: Self {
    let next = LockIsolated(StackElementID(generation: 0))
    return Self(
      next: {
        defer {
          next.withValue { $0 = StackElementID(generation: $0.generation + 1) }
        }
        return next.value
      },
      peek: { next.value }
    )
  }

  public static var testValue: Self {
    let next = LockIsolated(StackElementID(generation: 0))
    return Self(
      next: {
        defer {
          next.withValue {
            $0 = StackElementID(generation: $0.generation + 1)
          }
        }
        return next.value
      },
      peek: { next.value }
    )
  }

  func incrementingCopy() -> Self {
    let peek = self.peek()
    let next = LockIsolated(StackElementID(generation: peek.generation))
    return Self(
      next: {
        defer {
          next.withValue {
            $0 = StackElementID(generation: $0.generation + 1)
          }
        }
        return next.value
      },
      peek: { next.value }
    )
  }
}
