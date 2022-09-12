import CustomDump
import SwiftUI

/// A property wrapper type that can designate properties of app state that can be directly
/// bindable in SwiftUI views.
///
/// Along with an action type that conforms to the ``BindableAction`` protocol, this type can be
/// used to safely eliminate the boilerplate that is typically incurred when working with multiple
/// mutable fields on state.
///
/// For example, a settings screen may model its state with the following struct:
///
/// ```swift
/// struct SettingsState {
///   var digest = Digest.daily
///   var displayName = ""
///   var enableNotifications = false
///   var isLoading = false
///   var protectMyPosts = false
///   var sendEmailNotifications = false
///   var sendMobileNotifications = false
/// }
/// ```
///
/// The majority of these fields should be editable by the view, and in the Composable
/// Architecture this means that each field requires a corresponding action that can be sent to
/// the store. Typically this comes in the form of an enum with a case per field:
///
/// ```swift
/// enum SettingsAction {
///   case digestChanged(Digest)
///   case displayNameChanged(String)
///   case enableNotificationsChanged(Bool)
///   case protectMyPostsChanged(Bool)
///   case sendEmailNotificationsChanged(Bool)
///   case sendMobileNotificationsChanged(Bool)
/// }
/// ```
///
/// And we're not even done yet. In the reducer we must now handle each action, which simply
/// replaces the state at each field with a new value:
///
/// ```swift
/// let settingsReducer = Reducer<
///   SettingsState, SettingsAction, SettingsEnvironment
/// > { state, action, environment in
///   switch action {
///   case let digestChanged(digest):
///     state.digest = digest
///     return .none
///
///   case let displayNameChanged(displayName):
///     state.displayName = displayName
///     return .none
///
///   case let enableNotificationsChanged(isOn):
///     state.enableNotifications = isOn
///     return .none
///
///   case let protectMyPostsChanged(isOn):
///     state.protectMyPosts = isOn
///     return .none
///
///   case let sendEmailNotificationsChanged(isOn):
///     state.sendEmailNotifications = isOn
///     return .none
///
///   case let sendMobileNotificationsChanged(isOn):
///     state.sendMobileNotifications = isOn
///     return .none
///   }
/// }
/// ```
///
/// This is a _lot_ of boilerplate for something that should be simple. Luckily, we can
/// dramatically eliminate this boilerplate using `BindableState` and ``BindableAction``.
///
/// First, we can annotate each bindable value of state with the `@BindableState` property
/// wrapper:
///
/// ```swift
/// struct SettingsState {
///   @BindableState var digest = Digest.daily
///   @BindableState var displayName = ""
///   @BindableState var enableNotifications = false
///   var isLoading = false
///   @BindableState var protectMyPosts = false
///   @BindableState var sendEmailNotifications = false
///   @BindableState var sendMobileNotifications = false
/// }
/// ```
///
/// Each annotated field is directly to bindable to SwiftUI controls, like pickers, toggles, and
/// text fields. Notably, the `isLoading` property is _not_ annotated as being bindable, which
/// prevents the view from mutating this value directly.
///
/// Next, we can conform the action type to ``BindableAction`` by collapsing all of the
/// individual, field-mutating actions into a single case that holds a ``BindingAction`` generic
/// over the reducer's `SettingsState`:
///
/// ```swift
/// enum SettingsAction: BindableAction {
///   case binding(BindingAction<SettingsState>)
/// }
/// ```
///
/// And then, we can simplify the settings reducer by allowing the `binding` method to handle
/// these field mutations for us:
///
/// ```swift
/// let settingsReducer = Reducer<
///   SettingsState, SettingsAction, SettingsEnvironment
/// > {
///   switch action {
///   case .binding:
///     return .none
///   }
/// }
/// .binding()
/// ```
///
/// Binding actions are constructed and sent to the store by calling
/// ``ViewStore/binding(_:file:fileID:line:)`` with a key path to the bindable state:
///
/// ```swift
/// TextField("Display name", text: viewStore.binding(\.$displayName))
/// ```
///
/// Should you need to layer additional functionality over these bindings, your reducer can
/// pattern match the action for a given key path:
///
/// ```swift
/// case .binding(\.$displayName):
///   // Validate display name
///
/// case .binding(\.$enableNotifications):
///   // Return an authorization request effect
/// ```
///
/// Binding actions can also be tested in much the same way regular actions are tested. Rather
/// than send a specific action describing how a binding changed, such as
/// `.displayNameChanged("Blob")`, you will send a ``Reducer/binding(action:)`` action that
/// describes which key path is being set to what value, such as `.set(\.$displayName, "Blob")`:
///
/// ```swift
/// let store = TestStore(
///   initialState: SettingsState(),
///   reducer: settingsReducer,
///   environment: SettingsEnvironment(...)
/// )
///
/// store.send(.set(\.$displayName, "Blob")) {
///   $0.displayName = "Blob"
/// }
/// store.send(.set(\.$protectMyPosts, true)) {
///   $0.protectMyPosts = true
/// )
/// ```
@dynamicMemberLookup
@propertyWrapper
public struct BindableState<Value> {
  /// The underlying value wrapped by the bindable state.
  public var wrappedValue: Value

  /// Creates bindable state from the value of another bindable state.
  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  /// A projection that can be used to derive bindings from a view store.
  ///
  /// Use the projected value to derive bindings from a view store with properties annotated with
  /// `@BindableState`. To get the `projectedValue`, prefix the property with `$`:
  ///
  /// ```swift
  /// TextField("Display name", text: viewStore.binding(\.$displayName))
  /// ```
  ///
  /// See ``BindableState`` for more details.
  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  /// Returns bindable state to the resulting value of a given key path.
  ///
  /// - Parameter keyPath: A key path to a specific resulting value.
  /// - Returns: A new bindable state.
  public subscript<Subject>(
    dynamicMember keyPath: WritableKeyPath<Value, Subject>
  ) -> BindableState<Subject> {
    get { .init(wrappedValue: self.wrappedValue[keyPath: keyPath]) }
    set { self.wrappedValue[keyPath: keyPath] = newValue.wrappedValue }
  }
}

extension BindableState: Equatable where Value: Equatable {}

extension BindableState: Hashable where Value: Hashable {}

extension BindableState: Decodable where Value: Decodable {
  public init(from decoder: Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()
      self.init(wrappedValue: try container.decode(Value.self))
    } catch {
      self.init(wrappedValue: try Value(from: decoder))
    }
  }
}

extension BindableState: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

extension BindableState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}

extension BindableState: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

extension BindableState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.wrappedValue.debugDescription
  }
}

/// An action type that exposes a `binding` case that holds a ``BindingAction``.
///
/// Used in conjunction with ``BindableState`` to safely eliminate the boilerplate typically
/// associated with mutating multiple fields in state.
///
/// See the documentation for ``BindableState`` for more details.
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
    _ keyPath: WritableKeyPath<State, BindableState<Value>>,
    _ value: Value
  ) -> Self {
    self.binding(.set(keyPath, value))
  }
}

extension ViewStore where Action: BindableAction, Action.State == State {
  /// Returns a binding to the resulting bindable state of a given key path.
  ///
  /// - Parameter keyPath: A key path to a specific bindable state.
  /// - Returns: A new binding.
  public func binding<Value: Equatable>(
    _ keyPath: WritableKeyPath<State, BindableState<Value>>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let debugger = BindableActionViewStoreDebugger(
            value: value, bindableActionType: Action.self, file: file, fileID: fileID, line: line
          )
          let set: (inout State) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: (inout State) -> Void = { $0[keyPath: keyPath].wrappedValue = value }
        #endif
        return .binding(.init(keyPath: keyPath, set: set, value: value))
      }
    )
  }
}

/// An action that describes simple mutations to some root state at a writable key path.
///
/// Used in conjunction with ``BindableState`` and ``BindableAction`` to safely eliminate the
/// boilerplate typically associated with mutating multiple fields in state.
///
/// See the documentation for ``BindableState`` for more details.
public struct BindingAction<Root>: Equatable {
  public let keyPath: PartialKeyPath<Root>

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
  ///     annotated with the ``BindableState`` property wrapper.
  ///   - value: A value to assign at the given key path.
  /// - Returns: An action that describes simple mutations to some root state at a writable key
  ///   path.
  public static func set<Value: Equatable>(
    _ keyPath: WritableKeyPath<Root, BindableState<Value>>,
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
    keyPath: WritableKeyPath<Root, BindableState<Value>>,
    bindingAction: Self
  ) -> Bool {
    keyPath == bindingAction.keyPath
  }

  init<Value: Equatable>(
    keyPath: WritableKeyPath<Root, BindableState<Value>>,
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
  /// when the domain contains ``BindableState`` and ``BindableAction``.
  ///
  /// For example, we can model an app that can bind an integer count to a stepper and make a
  /// network request to fetch a fact about that integer with the following domain:
  ///
  /// ```swift
  /// struct AppState: Equatable {
  ///   @BindableState var count = 0
  ///   var fact: String?
  ///   ...
  /// }
  ///
  /// enum AppAction: BindableAction {
  ///   case binding(BindingAction<AppState>)
  ///   case factButtonTapped
  ///   case factResponse(String?)
  ///   ...
  /// }
  ///
  /// struct AppEnvironment {
  ///   var numberFact: (Int) async throws -> String
  ///   ...
  /// }
  ///
  /// let appReducer = Reducer<AppState, AppAction, AppEnvironment> {
  ///   ...
  /// }
  /// .binding()
  ///
  /// struct AppView: View {
  ///   let store: Store
  ///
  ///   var view: some View {
  ///     ...
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
  /// extension AppView {
  ///   struct ViewState: Equatable {
  ///     @BindableState var count: Int
  ///     let fact: String?
  ///     // no access to any other state on `AppState`, like child domains
  ///   }
  ///
  ///   enum ViewAction: BindableAction {
  ///     case binding(BindingAction<ViewState>)
  ///     case factButtonTapped
  ///     // no access to any other action on `AppAction`, like `factResponse`
  ///   }
  /// }
  /// ```
  ///
  /// In order to transform a `BindingAction<ViewState>` sent from the view domain into a
  /// `BindingAction<AppState>`, we need a writable key path from `AppState` to `ViewState`. We
  /// can synthesize one by defining a computed property on `AppState` with a getter and a setter.
  /// The setter should communicate any mutations to bindable state back to the parent state:
  ///
  /// ```swift
  /// extension AppState {
  ///   var view: AppView.ViewState {
  ///     get { .init(count: self.count, fact: self.fact) }
  ///     set { self.count = newValue.count }
  ///   }
  /// }
  /// ```
  ///
  /// With this property defined it is now possible to transform a `BindingAction<ViewState>` into
  /// a `BindingAction<AppState>`, which means we can transform a `ViewAction` into an
  /// `AppAction`. This is where `pullback` comes into play: we can unwrap the view action's
  /// binding action on view state and transform it with `pullback` to work with app state. We can
  /// define a helper that performs this transformation, as well as route any other view actions
  /// to their reducer equivalents:
  ///
  /// ```swift
  /// extension AppAction {
  ///   static func view(_ viewAction: AppView.ViewAction) -> Self {
  ///     switch viewAction {
  ///     case let .binding(action):
  ///       // transform view binding actions into app binding actions
  ///       return .binding(action.pullback(\.view))
  ///
  ///     case let .factButtonTapped
  ///       // route `ViewAction.factButtonTapped` to `AppAction.factButtonTapped`
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
  ///   self.store, observe: \.view, send: AppAction.view
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
    .init(
      self,
      children: [
        "set": (self.keyPath, self.value)
      ],
      displayStyle: .enum
    )
  }
}

extension Reducer where Action: BindableAction, State == Action.State {
  /// Returns a reducer that applies ``BindingAction`` mutations to `State` before running this
  /// reducer's logic.
  ///
  /// For example, a settings screen may gather its binding actions into a single
  /// ``BindingAction`` case by conforming to ``BindableAction``:
  ///
  /// ```swift
  /// enum SettingsAction: BindableAction {
  ///   ...
  ///   case binding(BindingAction<SettingsState>)
  /// }
  /// ```
  ///
  /// The reducer can then be enhanced to automatically handle these mutations for you by tacking
  /// on the ``binding()`` method:
  ///
  /// ```swift
  /// let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> {
  ///   ...
  /// }
  /// .binding()
  /// ```
  ///
  /// - Returns: A reducer that applies ``BindingAction`` mutations to `State` before running this
  ///   reducer's logic.
  public func binding() -> Self {
    Self { state, action, environment in
      guard let bindingAction = (/Action.binding).extract(from: action)
      else {
        return self.run(&state, action, environment)
      }

      bindingAction.set(&state)
      return self.run(&state, action, environment)
    }
  }
}

#if DEBUG
  private final class BindableActionViewStoreDebugger<Value> {
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
        runtimeWarning(
          """
          A binding action sent from a view store at "%@:%d" was not handled. …

            Action:
              %@

          To fix this, invoke the "binding()" method on your feature's reducer.
          """,
          [
            "\(self.fileID)",
            self.line,
            "\(self.bindableActionType).binding(.set(_, \(self.value)))",
          ],
          file: self.file,
          line: self.line
        )
        return
      }
    }
  }
#endif
