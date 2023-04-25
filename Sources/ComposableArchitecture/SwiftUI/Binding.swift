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
  /// The underlying value wrapped by the binding state.
  public var wrappedValue: Value

  /// Creates binding state from the value of another binding state.
  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  /// A projection that can be used to derive bindings from a view store.
  ///
  /// Use the projected value to derive bindings from a view store with properties annotated with
  /// `@BindingState`. To get the `projectedValue`, prefix the property with `$`:
  ///
  /// ```swift
  /// TextField("Display name", text: viewStore.binding(\.$displayName))
  /// ```
  ///
  /// See ``BindingState`` for more details.
  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  /// Returns binding state to the resulting value of a given key path.
  ///
  /// - Parameter keyPath: A key path to a specific resulting value.
  /// - Returns: A new binding state.
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

extension BindingState: Sendable where Value: Sendable {}

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
  /// Returns a binding to the resulting binding state of a given key path.
  ///
  /// - Parameter keyPath: A key path to a specific binding state.
  /// - Returns: A new binding.
  public func binding<Value: Equatable>(
    _ keyPath: WritableKeyPath<ViewState, BindingState<Value>>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let debugger = BindableActionViewStoreDebugger(
            value: value, bindableActionType: ViewAction.self, fileID: fileID, line: line
          )
          let set: (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: (inout ViewState) -> Void = { $0[keyPath: keyPath].wrappedValue = value }
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
  // NB: swift(<5.8) has an enum existential layout bug that can cause crashes when extracting
  //     payloads. We can box the existential to work around the bug.
  #if swift(<5.8)
    private let _value: [Any]
    var value: Any { self._value[0] }
  #else
    let value: Any
  #endif
  let valueIsEqualTo: (Any) -> Bool

  init(
    keyPath: PartialKeyPath<Root>,
    set: @escaping (inout Root) -> Void,
    value: Any,
    valueIsEqualTo: @escaping (Any) -> Bool
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
  /// binding state and bindable action:
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
  /// getter and a setter. The setter should communicate any mutations to binding state back to the
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
  ///   static func view(_ viewAction: MyFeatureView.ViewAction) -> Self {
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
  ///   Stepper("\(viewStore.count)", viewStore.binding(\.$count))
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
  private final class BindableActionViewStoreDebugger<Value> {
    let value: Value
    let bindableActionType: Any.Type
    let fileID: StaticString
    let line: UInt
    var wasCalled = false

    init(
      value: Value,
      bindableActionType: Any.Type,
      fileID: StaticString,
      line: UInt
    ) {
      self.value = value
      self.bindableActionType = bindableActionType
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
          """
        )
        return
      }
    }
  }
#endif
