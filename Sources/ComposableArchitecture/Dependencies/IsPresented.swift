extension DependencyValues {
  /// A Boolean value that indicates whether the current feature is being presented from a parent
  /// feature.
  ///
  /// This value is set to true on reducers that are run from within
  /// ``Reducer/ifLet(_:action:destination:fileID:line:)`` and
  /// ``Reducer/forEach(_:action:destination:fileID:line:)``.
  public var isPresented: Bool {
    self.dismiss.dismiss != nil
  }
}
