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

/// A property wrapper type that can designate properties of view state that can be directly
/// bindable in SwiftUI views.
///
/// Read <doc:Bindings> for more information.
@dynamicMemberLookup
@propertyWrapper
public struct BindingViewState<Value> {
  let binding: Binding<Value>
  let initialValue: Value

  init(binding: Binding<Value>) {
    self.binding = binding
    self.initialValue = binding.wrappedValue
  }

  public var wrappedValue: Value {
    get { self.binding.wrappedValue }
    set { self.binding.wrappedValue = newValue }
  }

  public var projectedValue: Binding<Value> {
    self.binding
  }

  public subscript<Subject>(
    dynamicMember keyPath: WritableKeyPath<Value, Subject>
  ) -> BindingViewState<Subject> {
    BindingViewState<Subject>(binding: self.binding[dynamicMember: keyPath])
  }
}

extension BindingViewState: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.initialValue == rhs.initialValue && lhs.wrappedValue == rhs.wrappedValue
  }
}

extension BindingViewState: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.initialValue)
    hasher.combine(self.wrappedValue)
  }
}

extension BindingViewState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}

extension BindingViewState: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

extension BindingViewState: CustomDebugStringConvertible
where Value: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.wrappedValue.debugDescription
  }
}

/// A property wrapper type that can derive ``BindingViewState`` values for a ``ViewStore``.
///
/// Read <doc:Bindings> for more information.
@dynamicMemberLookup
@propertyWrapper
@preconcurrency @MainActor
public struct BindingViewStore<State> {
  let store: Store<State, BindingAction<State>>
  #if DEBUG
    let bindableActionType: Any.Type
    let fileID: StaticString
    let filePath: StaticString
    let line: UInt
    let column: UInt
  #endif

  init<Action: BindableAction<State>>(
    store: Store<State, Action>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.store = store._scope(state: { $0 }, action: { .binding($0) })
    #if DEBUG
      self.bindableActionType = type(of: Action.self)
      self.fileID = fileID
      self.filePath = filePath
      self.line = line
      self.column = column
    #endif
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public var wrappedValue: State {
    self.store.withState { $0 }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.wrappedValue[keyPath: keyPath]
  }
}

#if DEBUG
  final class BindableActionViewStoreDebugger<Value: Sendable>: Sendable {
    enum Context {
      case bindingState
      case bindingStore
      case viewStore
    }

    let value: Value
    let bindableActionType: Any.Type
    let context: Context
    let isInvalidated: @MainActor @Sendable () -> Bool
    let fileID: StaticString
    let filePath: StaticString
    let line: UInt
    let column: UInt
    let wasCalled = LockIsolated(false)

    init(
      value: Value,
      bindableActionType: Any.Type,
      context: Context,
      isInvalidated: @escaping @MainActor @Sendable () -> Bool,
      fileID: StaticString,
      filePath: StaticString,
      line: UInt,
      column: UInt
    ) {
      self.value = value
      self.bindableActionType = bindableActionType
      self.context = context
      self.isInvalidated = isInvalidated
      self.fileID = fileID
      self.filePath = filePath
      self.line = line
      self.column = column
    }

    deinit {
      guard !self.wasCalled.value
      else { return }

      Task {
        @MainActor [
          context, fileID, filePath, line, column, value, bindableActionType, isInvalidated
        ] in
        let tmp = isInvalidated()
        guard !tmp else { return }
        var valueDump: String {
          var valueDump = ""
          customDump(value, to: &valueDump, maxDepth: 0)
          return valueDump
        }
        reportIssue(
          """
          A binding action sent from a store \
          \(context == .bindingState ? "for binding state defined " : "")at \
          "\(fileID):\(line)" was not handled.

            Action:
              \(typeName(bindableActionType)).binding(.set(_, \(valueDump)))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """,
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
      }
    }
  }
#endif
