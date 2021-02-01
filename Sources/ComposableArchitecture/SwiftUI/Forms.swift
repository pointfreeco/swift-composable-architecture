import CasePaths
import SwiftUI

/// An action that describes simple mutations to some root state at a writable key path.
///
/// This type can be used to eliminate the boilerplate that is typically incurred when working with
/// multiple mutable fields on state.
///
/// For example, a settings screen may model its state with the following struct:
///
///     struct SettingsState {
///       var digest = Digest.daily
///       var displayName = ""
///       var enableNotifications = false
///       var protectMyPosts = false
///       var sendEmailNotifications = false
///       var sendMobileNotifications = false
///     }
///
/// Each of these fields should be editable, and in the Composable Architecture this means that each
/// field requires a corresponding action that can be sent to the store. Typically this comes in the
/// form of an enum with a case per field:
///
///     enum SettingsAction {
///       case digestChanged(Digest)
///       case displayNameChanged(String)
///       case enableNotificationsChanged(Bool)
///       case protectMyPostsChanged(Bool)
///       case sendEmailNotificationsChanged(Bool)
///       case sendMobileNotificationsChanged(Bool)
///     }
///
/// And we're not even done yet. In the reducer we must now handle each action, which simply
/// replaces the state at each field with a new value:
///
///     let settingsReducer = Reducer<
///       SettingsState, SettingsAction, SettingsEnvironment
///     > { state, action, environment in
///       switch action {
///       case let digestChanged(digest):
///         state.digest = digest
///         return .none
///
///       case let displayNameChanged(displayName):
///         state.displayName = displayName
///         return .none
///
///       case let enableNotificationsChanged(isOn):
///         state.enableNotifications = isOn
///         return .none
///
///       case let protectMyPostsChanged(isOn):
///         state.protectMyPosts = isOn
///         return .none
///
///       case let sendEmailNotificationsChanged(isOn):
///         state.sendEmailNotifications = isOn
///         return .none
///
///       case let sendMobileNotificationsChanged(isOn):
///         state.sendMobileNotifications = isOn
///         return .none
///       }
///     }
///
/// This is a _lot_ of boilerplate for something that should be simple. Luckily, we can dramatically
/// eliminate this boilerplate using `FormAction`. First, we can collapse all of these
/// field-mutating actions into a single case that holds a `FormAction` generic over the reducer's
/// root `SettingsState`:
///
///     enum SettingsAction {
///       case form(FormAction<SettingsState>)
///     }
///
/// And then, we can simplify the settings reducer by allowing the `form` method to handle these
/// field mutations for us:
///
///     let settingsReducer = Reducer<
///       SettingsState, SettingsAction, SettingsEnvironment
///     > {
///       switch action {
///       case .form:
///         return .none
///       }
///     }
///     .form(action: /SettingsAction.form)
///
/// Form actions are constructed and sent to the store by providing a writable key path from root
/// state to the field being mutated. There is even a view store helper that simplifies this work.
/// You can derive a binding by specifying the key path and form action case:
///
///     TextField(
///       "Display name",
///       text: viewStore.binding(keyPath: \.displayName, send: SettingsAction.form)
///     )
///
/// Should you need to layer additional functionality over your form, your reducer can pattern match
/// the form action for a given key path:
///
///     case .form(\.displayName):
///       // Validate display name
///
///     case .form(\.enableNotifications):
///       // Return an authorization request effect
///
/// Form actions can also be tested in much the same way regular actions are tested. Rather than
/// send a specific action describing how a binding changed, such as `displayNameChanged("Blob")`,
/// you will send a `.form` action that describes which key path is being set to what value, such
/// as `.form(.set(\.displayName, "Blob"))`:
///
///     let store = TestStore(
///       initialState: SettingsState(),
///       reducer: settingsReducer,
///       environment: SettingsEnvironment(...)
///     )
///
///     store.assert(
///       .send(.form(.set(\.displayName, "Blob"))) {
///         $0.displayName = "Blob"
///       },
///       .send(.form(.set(\.protectMyPosts, true))) {
///         $0.protectMyPosts = true
///       )
///     )
///
public struct FormAction<Root>: Equatable {
  public let keyPath: PartialKeyPath<Root>
  
  fileprivate let set: (inout Root) -> Void
  private let value: Any
  private let valueIsEqualTo: (Any) -> Bool

  /// Returns an action that describes simple mutations to some root state at a writable key path.
  ///
  /// - Parameters:
  ///   - keyPath: A key path to the property that should be mutated.
  ///   - value: A value to assign at the given key path.
  /// - Returns: An action that describes simple mutations to some root state at a writable key
  ///   path.
  public static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self
  where Value: Equatable {
    .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath] = value },
      value: value,
      valueIsEqualTo: { $0 as? Value == value }
    )
  }

  /// Transforms a form action over some root state to some other type of root state given a key
  /// path.
  ///
  /// - Parameter keyPath: A key path from a new type of root state to the original root state.
  /// - Returns: A form action over a new type of root state.
  public func pullback<NewRoot>(_ keyPath: WritableKeyPath<NewRoot, Root>) -> FormAction<NewRoot> {
    .init(
      keyPath: (keyPath as AnyKeyPath).appending(path: self.keyPath) as! PartialKeyPath<NewRoot>,
      set: { self.set(&$0[keyPath: keyPath]) },
      value: self.value,
      valueIsEqualTo: self.valueIsEqualTo
    )
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
  }

  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    formAction: FormAction<Root>
  ) -> Bool {
    keyPath == formAction.keyPath
  }
}

extension Reducer {
  /// Returns a reducer that applies `FormAction` mutations to `State` before running this reducer's
  /// logic.
  ///
  /// For example, a settings screen may gather its form actions into a single `FormAction` case:
  ///
  ///     enum SettingsAction {
  ///       ...
  ///       case form(FormAction<SettingsState>)
  ///     }
  ///
  /// The reducer can then be enhanced to automatically handle these mutations for you by tacking on
  /// the `form` method:
  ///
  ///     let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment {
  ///       ...
  ///     }
  ///     .form(action: /SettingsAction.form)
  ///
  /// - Parameter toFormAction: A case path from this reducer's `Action` type to a `FormAction` over
  ///   this reducer's `State`.
  /// - Returns: A reducer that applies `FormAction` mutations to `State` before running this
  ///   reducer's logic.
  public func form(action toFormAction: CasePath<Action, FormAction<State>>) -> Self {
    Self { state, action, environment in
      toFormAction.extract(from: action)?.set(&state)
      return .none
    }
    .combined(with: self)
  }
}

extension ViewStore {
  /// Derives a binding from the store that mutates state at the given writable key path by wrapping
  /// a `FormAction` with the store's action type.
  ///
  /// For example, a text field binding can be created like this:
  ///
  ///     struct State { var text = "" }
  ///     enum Action { case form(FormAction<State>) }
  ///
  ///     TextField(
  ///       "Enter text",
  ///       text: viewStore.binding(keyPath: \.text, Action.form)
  ///     )
  ///
  /// - Parameters:
  ///   - keyPath: A writable key path from the view store's state to a mutable field
  ///   - action: A function that wraps a form action in the view store's action type.
  /// - Returns: A binding.
  public func binding<LocalState>(
    keyPath: WritableKeyPath<State, LocalState>,
    send action: @escaping (FormAction<State>) -> Action
  ) -> Binding<LocalState>
  where LocalState: Equatable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.set(keyPath, $0)) }
    )
  }
}
