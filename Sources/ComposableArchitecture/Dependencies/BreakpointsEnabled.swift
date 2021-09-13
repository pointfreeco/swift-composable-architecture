private enum BreakpointsEnabledKey: DependencyKey {
  static let defaultValue = true
  static let testValue = true
}

extension DependencyValues {
  public var breakpointsEnabled: Bool {
    get { self[BreakpointsEnabledKey.self] }
    set { self[BreakpointsEnabledKey.self] = newValue }
  }
}
