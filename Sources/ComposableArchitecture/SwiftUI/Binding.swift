import CustomDump
import SwiftUI

/// A property wrapper type that can designate properties of app state that can be directly bindable
/// in SwiftUI views.
///
/// Along with an action type that conforms to the ``BindableAction`` protocol, this type can be
/// used to safely eliminate the boilerplate that is typically incurred when working with multiple
/// mutable fields on state.
///
/// Read <doc:Bindings> for more information.
@dynamicMemberLookup
@propertyWrapper
public struct BindingState<Value> {
  /// The underlying value wrapped by the bindable state.
  public var wrappedValue: Value

  /// Creates bindable state from the value of another bindable state.
  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
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

  /// Returns bindable state to the resulting value of a given key path.
  ///
  /// - Parameter keyPath: A key path to a specific resulting value.
  /// - Returns: A new bindable state.
  @available(
    *,
    deprecated,
    message:
      """
      Chaining onto properties of bindable state is deprecated. Push '@BindingState' use to the \
      child state, instead.
      """
  )
  public subscript<Subject>(
    dynamicMember keyPath: WritableKeyPath<Value, Subject>
  ) -> BindingState<Subject> {
    get { .init(wrappedValue: self.wrappedValue[keyPath: keyPath]) }
    set { self.wrappedValue[keyPath: keyPath] = newValue.wrappedValue }
  }
}

extension BindingState: Equatable where Value: Equatable {}

extension BindingState: Hashable where Value: Hashable {}

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

/// A type from which you can generate ``BindingViewState``'s pointing to its `State` using dynamic
/// member lookup.
///
/// You don't create values of this type directly, but you can extract one using the
/// ``BindableStateProtocol/bindings`` property that is available when your state
@dynamicMemberLookup
public struct BindingViewStates<State> {
  private let state: State
  init(state: State) {
    self.state = state
  }
  public subscript<Value>(dynamicMember keyPath: WritableKeyPath<State, BindingState<Value>>)
    -> BindingViewState<Value>
  {
    return .init(
      wrappedValue: self.state[keyPath: keyPath].wrappedValue,
      keyPath: keyPath
    )
  }
}

/// A protocol that your feature's `State` should conform to in order to extract
/// ``BindingViewState`` values from ``BindableStateProtocol/binding``.
///
/// There is no specific requirement to conform to this protocol.
///
/// - Note: This protocol will be renamed `BindableState` in a future release, when the deprecated
/// ``BindableState`` as a property wrapper will be obsoleted. At the same time, conforming to this
/// protocol will also be a requirement of ``BindingReducer``'s `State`, so you're invited to
/// conform states hosting `@BindingState` properties to this protocol already.
public protocol BindableStateProtocol {}

extension BindableStateProtocol {
  /// A ``BindingViewStates`` value from which you can extract ``BindingViewState``'s using
  /// dynamic lookup.
  ///
  /// You use this type as a `BindingViewState`'s repository to assign `@BindingViewState`
  /// properties in your `ViewState`s initializer:
  ///
  /// ```swift
  /// struct ViewState: Equatable {
  ///   @BindingViewState var text: String
  ///   init(state: State) {
  ///     self._text = state.bindings.$text
  ///   }
  /// }
  /// ```
  public var bindings: BindingViewStates<Self> {
    .init(state: self)
  }
  
  public subscript<Value>(keyPath: WritableKeyPath<Self, BindingState<Value>>) -> BindingViewState<Value> {
    .init(
      wrappedValue: self[keyPath: keyPath].wrappedValue,
      keyPath: keyPath
    )
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

/// A ``BindingState`` variant that is suitable for `ViewState`s.
///
/// You can only build these values using dynamic member lookup of ``BindingState`` properties on
/// the ``BindingViewStates`` value from ``BindableStateProtocol/bindings``.
///
/// Because you're defining the ``BindingViewState`` value directly, you must assign the value
/// of the property wrapper private storage using the underscored property name:
///
/// ```swift
/// struct ViewState: Equatable {
///   @BindingViewState var text: String
///   init(state: State) {
///     self._text = state.bindings.$text
///   }
/// }
/// ```
///
/// Read <doc:Bindings> for more information.
@propertyWrapper
public struct BindingViewState<Value> {
  let keyPath: AnyKeyPath
  public var wrappedValue: Value
  public var projectedValue: Self { self }
  internal init<State>(
    wrappedValue: Value,
    keyPath: WritableKeyPath<State, BindingState<Value>>
  ) {
    self.wrappedValue = wrappedValue
    self.keyPath = keyPath
  }
}
extension BindingViewState: Equatable where Value: Equatable {}

extension BindingViewState: Hashable where Value: Hashable {}

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

// `BindingViewState` dynamic member lookup.
extension ViewStore where ViewAction: BindableAction {
  public subscript<Value>(dynamicMember keyPath: KeyPath<ViewState, BindingViewState<Value>>)
    -> Binding<Value> where Value: Equatable
  {
    let stateKeyPath =
      self.state[keyPath: keyPath].keyPath
      as! WritableKeyPath<ViewAction.State, BindingState<Value>>
    return self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let debugger = BindableActionViewStoreDebugger(
            value: value,
            bindableActionType: ViewAction.self,
            // TODO: Restore context
            file: #file,
            fileID: #fileID,
            line: #line
          )
          let set: (inout ViewAction.State) -> Void = {
            $0[keyPath: stateKeyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: (inout ViewAction.State) -> Void = {
            $0[keyPath: stateKeyPath].wrappedValue = value
          }
        #endif

        return .binding(.init(keyPath: stateKeyPath, set: set, value: value))
      }
    )
  }
}

// `BindingState` from some `BindableStateProtocol` dynamic member lookup.
extension ViewStore
where
  ViewAction: BindableAction,
  ViewAction.State == ViewState,
  ViewAction.State: BindableStateProtocol
{
  public subscript<Value>(dynamicMember keyPath: WritableKeyPath<ViewState, BindingState<Value>>)
    -> Binding<Value> where Value: Equatable
  {
    return self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let debugger = BindableActionViewStoreDebugger(
            value: value,
            bindableActionType: ViewAction.self,
            // TODO: Restore context
            file: #file,
            fileID: #fileID,
            line: #line
          )
          let set: (inout ViewAction.State) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: (inout ViewAction.State) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
          }
        #endif

        return .binding(.init(keyPath: keyPath, set: set, value: value))
      }
    )
  }
}

/// An action that describes simple mutations to some root state at a writable key path.
///
/// Used in conjunction with ``BindingState`` and ``BindableAction`` to safely eliminate the
/// boilerplate typically associated with mutating multiple fields in state.
///
/// Read <doc:Bindings> for more information.
public struct BindingAction<Root>: Equatable {
  public let keyPath: PartialKeyPath<Root>

  @usableFromInline
  let set: (inout Root) -> Void
  let value: Any
  let valueIsEqualTo: (Any) -> Bool

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
  }
}

extension BindingAction {
  /// Returns an action that describes simple mutations to some root state at a writable key path
  /// to bindable state.
  ///
  /// - Parameters:
  ///   - keyPath: A key path to the property that should be mutated. This property must be
  ///     annotated with the ``BindingState`` property wrapper.
  ///   - value: A value to assign at the given key path.
  /// - Returns: An action that describes simple mutations to some root state at a writable key
  ///   path.
  public static func set<Value: Equatable>(
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

  init<Value: Equatable>(
    keyPath: WritableKeyPath<Root, BindingState<Value>>,
    set: @escaping (inout Root) -> Void,
    value: Value
  ) {
    self.init(
      keyPath: keyPath,
      set: set,
      value: value,
      valueIsEqualTo: { $0 as? Value == value }
    )
  }
}

extension BindingAction {
  /// Transforms a binding action over some root state to some other type of root state given a
  /// key path.
  ///
  /// Useful in transforming binding actions on view state into binding actions on reducer state
  /// when the domain contains ``BindingState`` and ``BindableAction``.
  ///
  /// For example, we can model an feature that can bind an integer count to a stepper and make a
  /// network request to fetch a fact about that integer with the following domain:
  ///
  /// ```swift
  /// struct MyFeature: ReducerProtocol {
  ///   struct State: Equatable {
  ///     @BindingState var count = 0
  ///     var fact: String?
  ///     ...
  ///   }
  ///
  ///   enum Action: BindableAction {
  ///     case binding(BindingAction<State>)
  ///     case factButtonTapped
  ///     case factResponse(String?)
  ///     ...
  ///   }
  ///
  ///   @Dependency(\.numberFact) var numberFact
  ///
  ///   var body: some ReducerProtocol<State, Action> {
  ///     BindingReducer()
  ///     // ...
  ///   }
  /// }
  ///
  /// struct MyFeatureView: View {
  ///   let store: StoreOf<MyFeature>
  ///
  ///   var view: some View {
  ///     // ...
  ///   }
  /// }
  /// ```
  ///
  /// The view may want to limit the state and actions it has access to by introducing a
  /// view-specific domain that contains only the state and actions the view needs. Not only will
  /// this minimize the number of times a view's `body` is computed, it will prevent the view
  /// from accessing state or sending actions outside its purview. We can define it with its own
  /// bindable state and bindable action:
  ///
  /// ```swift
  /// extension MyFeatureView {
  ///   struct ViewState: Equatable {
  ///     @BindingState var count: Int
  ///     let fact: String?
  ///     // no access to any other state on `MyFeature.State`, like child domains
  ///   }
  ///
  ///   enum ViewAction: BindableAction {
  ///     case binding(BindingAction<ViewState>)
  ///     case factButtonTapped
  ///     // no access to any other action on `MyFeature.Action`, like `factResponse`
  ///   }
  /// }
  /// ```
  ///
  /// In order to transform a `BindingAction<ViewState>` sent from the view domain into a
  /// `BindingAction<MyFeature.State>`, we need a writable key path from `MyFeature.State` to
  /// `ViewState`. We can synthesize one by defining a computed property on `MyFeature.State` with a
  /// getter and a setter. The setter should communicate any mutations to bindable state back to the
  /// parent state:
  ///
  /// ```swift
  /// extension MyFeature.State {
  ///   var view: MyFeatureView.ViewState {
  ///     get { .init(count: self.count, fact: self.fact) }
  ///     set { self.count = newValue.count }
  ///   }
  /// }
  /// ```
  ///
  /// With this property defined it is now possible to transform a `BindingAction<ViewState>` into
  /// a `BindingAction<MyFeature.State>`, which means we can transform a `ViewAction` into an
  /// `MyFeature.Action`. This is where `pullback` comes into play: we can unwrap the view action's
  /// binding action on view state and transform it with `pullback` to work with feature state. We
  /// can define a helper that performs this transformation, as well as route any other view actions
  /// to their reducer equivalents:
  ///
  /// ```swift
  /// extension MyFeature.Action {
  ///   static func view(_ viewAction: MyFeature.View.ViewAction) -> Self {
  ///     switch viewAction {
  ///     case let .binding(action):
  ///       // transform view binding actions into feature binding actions
  ///       return .binding(action.pullback(\.view))
  ///
  ///     case let .factButtonTapped
  ///       // route `ViewAction.factButtonTapped` to `MyFeature.Action.factButtonTapped`
  ///       return .factButtonTapped
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Finally, in the view we can invoke ``Store/scope(state:action:)`` with these domain
  /// transformations to leverage the view store's binding helpers:
  ///
  /// ```swift
  /// WithViewStore(
  ///   self.store, observe: \.view, send: MyFeature.Action.view
  /// ) { viewStore in
  ///   Stepper("\(viewStore.count)", viewStore.$count)
  ///   Button("Get number fact") { viewStore.send(.factButtonTapped) }
  ///   if let fact = viewStore.fact {
  ///     Text(fact)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter keyPath: A key path from a new type of root state to the original root state.
  /// - Returns: A binding action over a new type of root state.
  public func pullback<NewRoot>(
    _ keyPath: WritableKeyPath<NewRoot, Root>
  ) -> BindingAction<NewRoot> {
    .init(
      keyPath: (keyPath as AnyKeyPath).appending(path: self.keyPath) as! PartialKeyPath<NewRoot>,
      set: { self.set(&$0[keyPath: keyPath]) },
      value: self.value,
      valueIsEqualTo: self.valueIsEqualTo
    )
  }
}

extension BindingAction: CustomDumpReflectable {
  public var customDumpMirror: Mirror {
    Mirror(
      self,
      children: [
        "set": (self.keyPath, self.value)
      ],
      displayStyle: .enum
    )
  }
}

#if DEBUG
  final class BindableActionViewStoreDebugger<Value> {
    let value: Value
    let bindableActionType: Any.Type
    let file: StaticString
    let fileID: StaticString
    let line: UInt
    var wasCalled = false

    init(
      value: Value,
      bindableActionType: Any.Type,
      file: StaticString,
      fileID: StaticString,
      line: UInt
    ) {
      self.value = value
      self.bindableActionType = bindableActionType
      self.file = file
      self.fileID = fileID
      self.line = line
    }

    deinit {
      guard self.wasCalled else {
        runtimeWarn(
          """
          A binding action sent from a view store at "\(self.fileID):\(self.line)" was not \
          handled. …

            Action:
              \(typeName(self.bindableActionType)).binding(.set(_, \(self.value)))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """,
          file: self.file,
          line: self.line
        )
        return
      }
    }
  }
#endif
