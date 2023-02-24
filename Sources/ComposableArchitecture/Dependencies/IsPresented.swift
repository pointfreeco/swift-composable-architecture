extension DependencyValues {
  /// A Boolean value that indicates whether the current feature is being presented from a parent
  /// feature.
  ///
  /// This value is set to true on reducers that are run from within
  /// ``ReducerProtocol/ifLet(_:action:destination:file:fileID:line:)-2soon``.
  public var isPresented: Bool {
    self.dismiss.dismiss != nil
  }
}
