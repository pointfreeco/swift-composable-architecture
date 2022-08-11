extension DependencyValues {
  public var dismiss: DismissEffect {
    get { self[DismissKey.self] }
    set { self[DismissKey.self] = newValue }
  }

  private enum DismissKey: LiveDependencyKey {
    static let liveValue = DismissEffect()
    static var testValue = DismissEffect()
  }
}

public struct DismissEffect: Sendable {
  private var dismiss: (@Sendable () async -> Void)?

  public func callAsFunction(
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) async {
    guard let dismiss = self.dismiss
    else {
      // TODO: Finesse language.
      runtimeWarning(
        """
        Dismissed from "%@:%d".
        """,
        [
          "\(fileID)",
          line
        ],
        file: file,
        line: line
      )
      return
    }
    await dismiss()
  }
}

extension DismissEffect {
  public init(_ dismiss: @escaping @Sendable () async -> Void) {
    self.dismiss = dismiss
  }
}
