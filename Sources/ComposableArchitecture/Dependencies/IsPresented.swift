extension DependencyValues {
  /// A Boolean value that indicates whether the current feature is being presented from a parent
  /// feature.
  ///
  /// This value is set to true on reducers that are run from within
  /// ``ReducerProtocol/presentationDestination(_:action:destination:file:fileID:line:)-7abw3``
  /// or ``ReducerProtocol/navigationDestination(_:action:destinations:file:fileID:line:)-1wldk``.
  public var isPresented: Bool {
    self.dismiss.dismiss != nil
  }
}
