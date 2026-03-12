import CustomDump
import SwiftUI

/// An action that describes simple mutations to some root state at a writable key path.
///
/// Used in conjunction with ``BindingState`` and ``BindableAction`` to safely eliminate the
/// boilerplate typically associated with mutating multiple fields in state.
///
/// Read <doc:Bindings> for more information.
public struct BindingAction<Root>: CasePathable, Equatable, Sendable {
  public let keyPath: _SendablePartialKeyPath<Root>

  @usableFromInline
  let set: @Sendable (inout Root) -> Void
  let value: any Sendable
  let valueIsEqualTo: @Sendable (Any) -> Bool

  init(
    keyPath: _SendablePartialKeyPath<Root>,
    set: @escaping @Sendable (inout Root) -> Void,
    value: any Sendable,
    valueIsEqualTo: @escaping @Sendable (Any) -> Bool
  ) {
    self.keyPath = keyPath
    self.set = set
    self.value = value
    self.valueIsEqualTo = valueIsEqualTo
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
  }

  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  @dynamicMemberLookup
  public struct AllCasePaths {
    public subscript<Value: Equatable & Sendable>(
      dynamicMember keyPath: WritableKeyPath<Root, Value>
    ) -> AnyCasePath<BindingAction, Value> where Root: ObservableState {
      let keyPath = keyPath.unsafeSendable()
      return AnyCasePath(
        embed: { .set(keyPath, $0) },
        extract: { $0.keyPath == keyPath ? $0.value as? Value : nil }
      )
    }
  }
}

extension BindingAction {
  /// Matches a binding action by its key path.
  ///
  /// Implicitly invoked when switching on a reducer's action and pattern matching on a binding
  /// action directly to do further work:
  ///
  /// ```swift
  /// case .binding(\.displayName): // Invokes the `~=` operator.
  ///   // Validate display name
  ///
  /// case .binding(\.enableNotifications):
  ///   // Return an authorization request effect
  /// ```
  public static func ~= <Value>(
    keyPath: _SendableWritableKeyPath<Root, Value>,
    bindingAction: Self
  ) -> Bool {
    keyPath == bindingAction.keyPath
  }
}

extension BindingAction: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    var description = ".set("
    customDump(self.keyPath, to: &description, maxDepth: 0)
    description.append(", ")
    customDump(self.value, to: &description, maxDepth: 0)
    description.append(")")
    return description
  }
}

/// An action type that exposes a `binding` case that holds a ``BindingAction``.
///
/// Used in conjunction with ``BindingState`` to safely eliminate the boilerplate typically
/// associated with mutating multiple fields in state.
///
/// Read <doc:Bindings> for more information.
public protocol BindableAction<State> {
  /// The root state type that contains bindable fields.
  associatedtype State

  /// Embeds a binding action in this action type.
  ///
  /// - Returns: A binding action.
  static func binding(_ action: BindingAction<State>) -> Self

  /// Extracts a binding action from this action type.
  var binding: BindingAction<State>? { get }
}

extension BindableAction {
  public var binding: BindingAction<State>? {
    AnyCasePath(unsafe: { .binding($0) }).extract(from: self)
  }
}
