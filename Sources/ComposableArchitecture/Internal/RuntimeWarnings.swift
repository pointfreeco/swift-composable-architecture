import Foundation
import IssueReporting

extension Notification.Name {
  @_documentation(visibility: private)
  @available(*, deprecated, renamed: "_runtimeWarning")
  public static let runtimeWarning = Self("ComposableArchitecture.runtimeWarning")

  /// A notification that is posted when a runtime warning is emitted.
  public static let _runtimeWarning = Self("ComposableArchitecture.runtimeWarning")
}
