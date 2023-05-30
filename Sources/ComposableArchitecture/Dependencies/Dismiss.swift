import SwiftUI

extension DependencyValues {
  /// An effect that dismisses the current presentation.
  ///
  /// See the documentation of ``DismissEffect`` for more information.
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
/// struct ChildFeature: ReducerProtocol {
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
/// ``ReducerProtocol/ifLet(_:action:destination:fileID:line:)`` or the
/// ``ReducerProtocol/forEach(_:action:destination:fileID:line:)`` operator, and then
/// dismisses _that_ feature. It performs the dismissal by either sending the
/// ``PresentationAction/dismiss`` in the case of `ifLet` or sending ``StackAction/popFrom(id:)``
/// in the case of `forEach`.
///
/// It is also possible to dismiss the feature using an animation by providing an argument to the
/// `dismiss` function:
///
/// ```swift
/// case .exitButtonTapped:
///   return .fireAndForget { await self.dismiss(animation: .default) }
/// ```
///
/// This will cause the `dismiss` or `popFrom(id:)` action to be sent with the particular animation.
///
/// > Warning: The `@Dependency(\.dismiss)` tool only works for features that are presented using
/// > the `ifLet` operator for tree-based navigation (see <doc:TreeBasedNavigation> for more info)
/// > or `forEach` operator for stack-based navigation (see <doc:StackBasedNavigation>). If no
/// > parent feature is found that was presented with `ifLet` or `forEach`, then a runtime warning
/// > is emitted in Xcode letting you know that it is not possible to dismiss. Further, the runtime
/// > warning becomes a test failure when run in tests.
/// >
/// > If you are testing a child feature in isolation that makes use of `@Dependency(\.dismiss)`
/// > then you will need to override the dependency to get a passing test. You can even mutate
/// > some shared mutable state inside the `dismiss` closure to confirm that it is indeed invoked:
/// >
/// > ```swift
/// > let isDismissInvoked = LockIsolated(false)
/// > let store = Store(initialState: Child.State()) {
/// >   Child()
/// > } withDependencies: {
/// >   $0.dismiss = { isDismissInvoked.setValue(true) }
/// > }
/// >
/// > await store.send(.exitButtonTapped) {
/// >   // ...
/// > }
/// > XCTAssertEqual(isDismissInvoked.value, true)
/// > ```
public struct DismissEffect: Sendable {
  var dismiss: (@MainActor @Sendable () -> Void)?

  @MainActor
  public func callAsFunction(
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) async {
    await self.callAsFunction(animation: nil, fileID: fileID, line: line)
  }

  @MainActor
  public func callAsFunction(
    animation: Animation?,
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
    withAnimation(animation) {
      dismiss()
    }
  }
}

extension DismissEffect {
  public init(_ dismiss: @escaping @MainActor @Sendable () -> Void) {
    self.dismiss = dismiss
  }
}

private enum DismissKey: DependencyKey {
  static let liveValue = DismissEffect()
  static var testValue = DismissEffect()
}
