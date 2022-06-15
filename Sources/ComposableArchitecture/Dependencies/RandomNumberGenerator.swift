// TODO: Should this be `withRandomNumberGenerator: ((inout any RandomNumberGenerator) -> R) -> R`?

extension DependencyValues {
  public var randomNumberGenerator: any RandomNumberGenerator {
    get { self[RandomNumberGeneratorKey.self] }
    set { self[RandomNumberGeneratorKey.self] = BoxedRandomNumberGenerator(rng: newValue) }
  }

  private enum RandomNumberGeneratorKey: LiveDependencyKey {
    static let liveValue: any RandomNumberGenerator = SystemRandomNumberGenerator()
    // TODO: Testable or failing RNG
    static let testValue: any RandomNumberGenerator = SystemRandomNumberGenerator()
  }

  private final class BoxedRandomNumberGenerator: RandomNumberGenerator {
    var rng: any RandomNumberGenerator

    init(rng: any RandomNumberGenerator) {
      self.rng = rng
    }

    func next() -> UInt64 {
      self.rng.next()
    }
  }
}
