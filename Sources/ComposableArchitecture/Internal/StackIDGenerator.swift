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

  init(startingAt generation: Int = 0) {
    let next = LockIsolated(StackElementID(generation: generation))
    self.next = {
      defer {
        next.withValue { $0 = StackElementID(generation: $0.generation + 1) }
      }
      return next.value
    }
    self.peek = { next.value }
  }

  @_spi(Internals)
  public func callAsFunction() -> StackElementID {
    self.next()
  }

  public static var liveValue: Self {
    Self()
  }

  public static var testValue: Self {
    Self()
  }

  func incrementingCopy() -> Self {
    Self(startingAt: self.peek().generation)
  }
}
