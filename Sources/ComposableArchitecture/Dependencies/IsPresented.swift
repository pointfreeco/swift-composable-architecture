extension DependencyValues {
  /// A Boolean value that indicates whether the current feature is being presented from a parent
  /// feature.
  ///
  /// This value is set to true on reducers that are run from within
  /// ``ReducerProtocol/ifLet(_:action:destination:fileID:line:)`` and
  /// ``ReducerProtocol/forEach(_:action:destination:fileID:line:)``.
  ///
  /// See ``DismissEffect`` for more information on how child features can easily dismiss themselves
  /// without communicating to the parent.
  public var isPresented: Bool {
    self.dismiss.dismiss != nil
  }
}
