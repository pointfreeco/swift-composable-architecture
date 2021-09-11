private enum UUIDKey: DependencyKey {
  static var defaultValue = { UUID() }
}

extension DependencyValues {
  public var uuid: () -> UUID {
    get { self[UUIDKey.self] }
    set { self[UUIDKey.self] = newValue }
  }
}
