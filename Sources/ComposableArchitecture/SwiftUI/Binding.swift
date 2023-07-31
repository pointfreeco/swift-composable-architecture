import CustomDump
import SwiftUI

/// A property wrapper type that can designate properties of app state that can be directly bindable
/// in SwiftUI views.
///
/// Along with an action type that conforms to the ``BindableAction`` protocol, this type can be
/// used to safely eliminate the boilerplate that is typically incurred when working with multiple
/// mutable fields on state.
///
/// > Note: It is not necessary to annotate _every_ field with `@BindingState`, and in fact it is
/// > not recommended. Marking a field with the property wrapper makes it instantly mutable from the
/// > outside, which may hurt the encapsulation of your feature. It is best to limit the usage of
/// > the property wrapper to only those fields that need to have bindings derived for handing to
/// > SwiftUI components.
///
/// Read <doc:Bindings> for more information.
@propertyWrapper
public struct BindingState<Value> {
  /// The underlying value wrapped by the binding state.
  public var wrappedValue: Value
  #if DEBUG
    let fileID: StaticString
    let line: UInt
  #endif

  /// Creates bindable state from the value of another bindable state.
  public init(
    wrappedValue: Value,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.wrappedValue = wrappedValue
    #if DEBUG
      self.fileID = fileID
      self.line = line
    #endif
  }

  /// A projection that can be used to derive bindings from a view store.
  ///
  /// Use the projected value to derive bindings from a view store with properties annotated with
  /// `@BindingState`. To get the `projectedValue`, prefix the property with `$`:
  ///
  /// ```swift
  /// TextField("Display name", text: viewStore.$displayName)
  /// ```
  ///
  /// See ``BindingState`` for more details.
  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

extension BindingState: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

extension BindingState: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    self.wrappedValue.hash(into: &hasher)
  }
}

extension BindingState: Decodable where Value: Decodable {
  public init(from decoder: Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()
      self.init(wrappedValue: try container.decode(Value.self))
    } catch {
      self.init(wrappedValue: try Value(from: decoder))
    }
  }
}

extension BindingState: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

extension BindingState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}

extension BindingState: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

extension BindingState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.wrappedValue.debugDescription
  }
}

extension BindingState: Sendable where Value: Sendable {}

/// An action that describes simple mutations to some root state at a writable key path.
///
/// Used in conjunction with ``BindingState`` and ``BindableAction`` to safely eliminate the
/// boilerplate typically associated with mutating multiple fields in state.
///
/// Read <doc:Bindings> for more information.
public struct BindingAction<Root>: Equatable, @unchecked Sendable {
  public let keyPath: PartialKeyPath<Root>

  @usableFromInline
  let set: @Sendable (inout Root) -> Void
  // NB: swift(<5.8) has an enum existential layout bug that can cause crashes when extracting
  //     payloads. We can box the existential to work around the bug.
  #if swift(<5.8)
    private let _value: [AnySendable]
    var value: AnySendable { self._value[0] }
  #else
    let value: AnySendable
  #endif
  let valueIsEqualTo: @Sendable (Any) -> Bool

  init(
    keyPath: PartialKeyPath<Root>,
    set: @escaping @Sendable (inout Root) -> Void,
    value: AnySendable,
    valueIsEqualTo: @escaping @Sendable (Any) -> Bool
  ) {
    self.keyPath = keyPath
    self.set = set
    #if swift(<5.8)
      self._value = [value]
    #else
      self.value = value
    #endif
    self.valueIsEqualTo = valueIsEqualTo
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
  }
}

struct AnySendable: @unchecked Sendable {
  let base: Any
  @inlinable
  init<Base: Sendable>(_ base: Base) {
    self.base = base
  }
}

extension BindingAction {
  /// Returns an action that describes simple mutations to some root state at a writable key path
  /// to binding state.
  ///
  /// - Parameters:
  ///   - keyPath: A key path to the property that should be mutated. This property must be
  ///     annotated with the ``BindingState`` property wrapper.
  ///   - value: A value to assign at the given key path.
  /// - Returns: An action that describes simple mutations to some root state at a writable key
  ///   path.
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<Root, BindingState<Value>>,
    _ value: Value
  ) -> Self {
    return .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath].wrappedValue = value },
      value: value
    )
  }

  /// Matches a binding action by its key path.
  ///
  /// Implicitly invoked when switching on a reducer's action and pattern matching on a binding
  /// action directly to do further work:
  ///
  /// ```swift
  /// case .binding(\.$displayName): // Invokes the `~=` operator.
  ///   // Validate display name
  ///
  /// case .binding(\.$enableNotifications):
  ///   // Return an authorization request effect
  /// ```
  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, BindingState<Value>>,
    bindingAction: Self
  ) -> Bool {
    keyPath == bindingAction.keyPath
  }

  init<Value: Equatable & Sendable>(
    keyPath: WritableKeyPath<Root, BindingState<Value>>,
    set: @escaping @Sendable (_ state: inout Root) -> Void,
    value: Value
  ) {
    self.init(
      keyPath: keyPath,
      set: set,
      value: AnySendable(value),
      valueIsEqualTo: { ($0 as? AnySendable)?.base as? Value == value }
    )
  }
}

extension BindingAction: CustomDumpStringConvertible {
  public var customDumpDescription: String {
    var description = ".set("
    customDump(self.keyPath, to: &description, maxDepth: 0)
    description.append(", ")
    customDump(self.value.base, to: &description, maxDepth: 0)
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
}

extension BindableAction {
  /// Constructs a binding action for the given key path and bindable value.
  ///
  /// Shorthand for `.binding(.set(\.$keyPath, value))`.
  ///
  /// - Returns: A binding action.
  public static func set<Value: Equatable>(
    _ keyPath: WritableKeyPath<State, BindingState<Value>>,
    _ value: Value
  ) -> Self {
    self.binding(.set(keyPath, value))
  }
}

extension ViewStore where ViewAction: BindableAction, ViewAction.State == ViewState {
  @MainActor
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<ViewState, BindingState<Value>>
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let bindingState = self.state[keyPath: keyPath]
          let debugger = BindableActionViewStoreDebugger(
            value: value,
            bindableActionType: ViewAction.self,
            context: .bindingState,
            isInvalidated: self._isInvalidated,
            fileID: bindingState.fileID,
            line: bindingState.line
          )
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
          }
        #endif
        return .binding(.init(keyPath: keyPath, set: set, value: value))
      }
    )
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
public struct BindingViewStore<State> {
  let store: Store<State, BindingAction<State>>
  #if DEBUG
    let bindableActionType: Any.Type
    let fileID: StaticString
    let line: UInt
  #endif

  init<Action: BindableAction>(
    store: Store<State, Action>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Action.State == State {
    self.store = store.scope(state: { $0 }, action: Action.binding)
    #if DEBUG
      self.bindableActionType = type(of: Action.self)
      self.fileID = fileID
      self.line = line
    #endif
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public var wrappedValue: State {
    self.store.state.value
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.wrappedValue[keyPath: keyPath]
  }

  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, BindingState<Value>>
  ) -> BindingViewState<Value> {
    BindingViewState(
      binding: ViewStore(self.store, observe: { $0[keyPath: keyPath].wrappedValue })
        .binding(
          send: { value in
            #if DEBUG
              let debugger = BindableActionViewStoreDebugger(
                value: value,
                bindableActionType: self.bindableActionType,
                context: .bindingStore,
                isInvalidated: self.store._isInvalidated,
                fileID: self.fileID,
                line: self.line
              )
              let set: @Sendable (inout State) -> Void = {
                $0[keyPath: keyPath].wrappedValue = value
                debugger.wasCalled = true
              }
            #else
              let set: @Sendable (inout State) -> Void = {
                $0[keyPath: keyPath].wrappedValue = value
              }
            #endif
            return .init(keyPath: keyPath, set: set, value: value)
          }
        )
    )
  }
}

extension ViewStore {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: { (_: State) in
        toViewState(BindingViewStore(store: store.scope(state: { $0 }, action: fromViewAction)))
      },
      send: fromViewAction,
      removeDuplicates: isDuplicate
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  @_disfavoredOverload
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate
    )
  }
}

extension ViewStore where ViewState: Equatable {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  @_disfavoredOverload
  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: fromViewAction,
      removeDuplicates: ==
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      removeDuplicates: ==
    )
  }
}

extension WithViewStore where Content: View {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: { (_: State) in
        toViewState(BindingViewStore(store: store.scope(state: { $0 }, action: fromViewAction)))
      },
      send: fromViewAction,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - isDuplicate: A function to determine when two `ViewState` values are equal. When values
  ///     are equal, repeat view computations are removed.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

extension WithViewStore where ViewState: Equatable, Content: View {
  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - fromViewAction: A function that transforms view actions into store action.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      send: fromViewAction,
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }

  /// Initializes a structure that transforms a ``Store`` into an observable ``ViewStore`` in order
  /// to compute bindings and views from state.
  ///
  /// Read <doc:Bindings> for more information.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - toViewState: A function that transforms binding store state into observable view state.
  ///     All changes to the view state will cause the `WithViewStore` to re-compute its view.
  ///   - content: A function that can generate content from a view store.
  @_disfavoredOverload
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction, ViewAction.State == State {
    self.init(
      store,
      observe: toViewState,
      removeDuplicates: ==,
      content: content,
      file: file,
      line: line
    )
  }
}

#if DEBUG
  private final class BindableActionViewStoreDebugger<Value> {
    enum Context {
      case bindingState
      case bindingStore
      case viewStore
    }

    let value: Value
    let bindableActionType: Any.Type
    let context: Context
    let isInvalidated: () -> Bool
    let fileID: StaticString
    let line: UInt
    var wasCalled = false

    init(
      value: Value,
      bindableActionType: Any.Type,
      context: Context,
      isInvalidated: @escaping () -> Bool,
      fileID: StaticString,
      line: UInt
    ) {
      self.value = value
      self.bindableActionType = bindableActionType
      self.context = context
      self.isInvalidated = isInvalidated
      self.fileID = fileID
      self.line = line
    }

    deinit {
      guard !self.isInvalidated() else { return }
      guard self.wasCalled else {
        var value = ""
        customDump(self.value, to: &value, maxDepth: 0)
        runtimeWarn(
          """
          A binding action sent from a view store \
          \(self.context == .bindingState ? "for binding state defined " : "")at \
          "\(self.fileID):\(self.line)" was not handled. …

            Action:
              \(typeName(self.bindableActionType)).binding(.set(_, \(value)))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """
        )
        return
      }
    }
  }
#endif
