extension DependencyValues {
  /// An action that dismisses the current presentation.
  public var dismiss: DismissEffect {
    get { self[DismissKey.self] }
    set { self[DismissKey.self] = newValue }
  }
}

public struct DismissEffect: Sendable {
  // TODO: Should this be `async throws`?
  private var dismiss: (@Sendable () async -> Void)?

  public func callAsFunction(
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) async {
    guard let dismiss = self.dismiss
    else {
      runtimeWarn(
        """
        A reducer requested dismissal at "\(fileID):\(line)", but couldn't be dismissed. …

        This is generally considered an application logic error, and can happen when a reducer \
        assumes it runs in a presentation destination. If a reducer can run at both the root level \
        of an application, as well as in a presentation destination, use \
        @Dependency(\\.isPresented) to determine if the reducer is being presented before calling \
        @Dependency(\\.dismiss).
        """
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

private enum DismissKey: DependencyKey {
  static let liveValue = DismissEffect()
  static var testValue = DismissEffect()
}
