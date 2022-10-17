extension DependencyValues {
  public var isPresented: Bool {
    self.navigationID.current != nil
  }
}
