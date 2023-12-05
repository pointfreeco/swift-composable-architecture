import CustomDump
import SwiftUI

/// An action that describes simple mutations to some root state at a writable key path.
///
/// Used in conjunction with ``BindingState`` and ``BindableAction`` to safely eliminate the
/// boilerplate typically associated with mutating multiple fields in state.
///
/// Read <doc:Bindings> for more information.
public struct BindingAction<Root>: CasePathable, Equatable, @unchecked Sendable {
  public let keyPath: PartialKeyPath<Root>
  public var value: Any { self._value.base }

  @usableFromInline
  let set: @Sendable (inout Root) -> Void
  // NB: swift(<5.8) has an enum existential layout bug that can cause crashes when extracting
  //     payloads. We can box the existential to work around the bug.
  #if swift(<5.8)
    private let _valueBox: [AnySendable]
    var _value: AnySendable { self._valueBox[0] }
  #else
    let _value: AnySendable
  #endif
  let valueIsEqualTo: @Sendable (Any) -> Bool

  @_spi(Internals)
  public init(
    keyPath: PartialKeyPath<Root>,
    set: @escaping @Sendable (inout Root) -> Void,
    value: AnySendable,
    valueIsEqualTo: @escaping @Sendable (Any) -> Bool
  ) {
    self.keyPath = keyPath
    self.set = set
    #if swift(<5.8)
      self._valueBox = [value]
    #else
      self._value = value
    #endif
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
    public subscript<Value: Equatable>(
      dynamicMember keyPath: WritableKeyPath<Root, Value>
    ) -> AnyCasePath<BindingAction, Value> where Root: ObservableState {
      AnyCasePath(
        embed: { .set(keyPath, $0) },
        extract: { $0.keyPath == keyPath ? $0.value as? Value : nil }
      )
    }
  }
}

@_spi(Internals)
public struct AnySendable: @unchecked Sendable {
  @usableFromInline
  let base: Any
  
  @_spi(Internals)
  public init<Base: Sendable>(_ base: Base) {
    self.base = base
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
public protocol BindableAction {
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
    AnyCasePath(unsafe: Self.binding).extract(from: self)
  }
}
