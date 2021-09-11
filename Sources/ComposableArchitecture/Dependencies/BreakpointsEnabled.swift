private enum BreakpointsEnabledKey: DependencyKey {
  static var defaultValue = true
}

extension DependencyValues {
  public var breakpointsEnabled: Bool {
    get { self[BreakpointsEnabledKey.self] }
    set { self[BreakpointsEnabledKey.self] = newValue }
  }
}
