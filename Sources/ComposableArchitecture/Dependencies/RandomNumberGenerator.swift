import Foundation

extension DependencyValues {
  public var withRandomNumberGenerator: WithRandomNumberGenerator {
    get { self[WithRandomNumberGeneratorKey.self] }
    set { self[WithRandomNumberGeneratorKey.self] = newValue }
  }

  private enum WithRandomNumberGeneratorKey: LiveDependencyKey {
    static let liveValue = WithRandomNumberGenerator(SystemRandomNumberGenerator())
    // TODO: Testable or failing RNG
    static let testValue = WithRandomNumberGenerator(SystemRandomNumberGenerator())
  }
}

public final class WithRandomNumberGenerator: @unchecked Sendable {
  private var generator: any RandomNumberGenerator
  private let lock: os_unfair_lock_t

  init(_ generator: some RandomNumberGenerator) {
    self.generator = generator
    self.lock = os_unfair_lock_t.allocate(capacity: 1)
    self.lock.initialize(to: os_unfair_lock())
  }

  deinit {
    self.lock.deinitialize(count: 1)
    self.lock.deallocate()
  }

  public func callAsFunction<R>(_ work: (inout any RandomNumberGenerator) -> R) -> R {
    self.lock.sync {
      work(&self.generator)
    }
  }
}
