extension DependencyValues {
  /// An effect that dismisses the current presentation.
  ///
  /// Execute this in the effect returned from a reducer in order to dismiss the feature:
  ///
  /// ```swift
  /// struct ChildFeature: Reducer {
  ///   struct State { /* ... */ }
  ///   enum Action {
  ///     case exitButtonTapped
  ///     // ...
  ///   }
  ///   @Dependency(\.dismiss) var dismiss
  ///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
  ///     switch action {
  ///       case .exitButtonTapped:
  ///         return .fireAndForget { await self.dismiss() }
  ///       // ...
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// This operation works by finding the nearest parent feature that was presented using either the
  /// ``ReducerProtocol/ifLet(_:action:then:file:fileID:line:)`` or the
  /// ``ReducerProtocol/forEach(_:action:destination:file:fileID:line:)`` operator, and then
  /// dismisses _that_ feature. If no such parent feature is found a runtime warning is emitted in
  /// Xcode letting you know that it is not possible to dismiss.
  public var dismiss: DismissEffect {
    get { self[DismissKey.self] }
    set { self[DismissKey.self] = newValue }
  }
}

/// An effect that dismisses the current presentation.
///
/// Execute this in the effect returned from a reducer in order to dismiss the feature:
///
/// ```swift
/// struct ChildFeature: Reducer {
///   struct State { /* ... */ }
///   enum Action {
///     case exitButtonTapped
///     // ...
///   }
///   @Dependency(\.dismiss) var dismiss
///   func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
///     switch action {
///       case .exitButtonTapped:
///         return .fireAndForget { await self.dismiss() }
///       // ...
///     }
///   }
/// }
/// ```
///
/// This operation works by finding the nearest parent feature that was presented using either the
/// ``ReducerProtocol/ifLet(_:action:then:file:fileID:line:)`` or the
/// ``ReducerProtocol/forEach(_:action:destination:file:fileID:line:)`` operator, and then dismisses
/// _that_ feature. If no such parent feature is found a runtime warning is emitted in Xcode letting
/// you know that it is not possible to dismiss.
public struct DismissEffect: Sendable {
  var dismiss: (@Sendable () async -> Void)?

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
        assumes it runs in a presentation context. If a reducer can run at both the root level \
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
