extension DependencyValues {
  public var randomNumberGenerator: any RandomNumberGenerator {
    get { self[RandomNumberGeneratorKey.self] }
    set { self[RandomNumberGeneratorKey.self] = newValue }
  }
}

private enum RandomNumberGeneratorKey: LiveDependencyKey {
  static let liveValue: any RandomNumberGenerator = SystemRandomNumberGenerator()
  // TODO: Testable RNG
  static let testValue: any RandomNumberGenerator = SystemRandomNumberGenerator()
}
