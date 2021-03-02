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
/// eliminate this boilerplate using `BindingAction`. First, we can collapse all of these
/// field-mutating actions into a single case that holds a `BindingAction` generic over the
/// reducer's root `SettingsState`:
///
///     enum SettingsAction {
///       case binding(BindingAction<SettingsState>)
///     }
///
/// And then, we can simplify the settings reducer by allowing the `binding` method to handle these
/// field mutations for us:
///
///     let settingsReducer = Reducer<
///       SettingsState, SettingsAction, SettingsEnvironment
///     > {
///       switch action {
///       case .binding:
///         return .none
///       }
///     }
///     .binding(action: /SettingsAction.binding)
///
/// Binding actions are constructed and sent to the store by providing a writable key path from root
/// state to the field being mutated. There is even a view store helper that simplifies this work.
/// You can derive a binding by specifying the key path and binding action case:
///
///     TextField(
///       "Display name",
///       text: viewStore.binding(keyPath: \.displayName, send: SettingsAction.binding)
///     )
///
/// Should you need to layer additional functionality over these bindings, your reducer can pattern
/// match the action for a given key path:
///
///     case .binding(\.displayName):
///       // Validate display name
///
///     case .binding(\.enableNotifications):
///       // Return an authorization request effect
///
/// Binding actions can also be tested in much the same way regular actions are tested. Rather than
/// send a specific action describing how a binding changed, such as `displayNameChanged("Blob")`,
/// you will send a `.binding` action that describes which key path is being set to what value, such
/// as `.binding(.set(\.displayName, "Blob"))`:
///
///     let store = TestStore(
///       initialState: SettingsState(),
///       reducer: settingsReducer,
///       environment: SettingsEnvironment(...)
///     )
///
///     store.assert(
///       .send(.binding(.set(\.displayName, "Blob"))) {
///         $0.displayName = "Blob"
///       },
///       .send(.binding(.set(\.protectMyPosts, true))) {
///         $0.protectMyPosts = true
///       )
///     )
///
public struct BindingAction<Root>: Equatable {
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

  /// Transforms a binding action over some root state to some other type of root state given a key
  /// path.
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

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
  }

  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    bindingAction: Self
  ) -> Bool {
    keyPath == bindingAction.keyPath
  }
}

extension Reducer {
  /// Returns a reducer that applies `BindingAction` mutations to `State` before running this
  /// reducer's logic.
  ///
  /// For example, a settings screen may gather its binding actions into a single `BindingAction`
  /// case:
  ///
  ///     enum SettingsAction {
  ///       ...
  ///       case binding(BindingAction<SettingsState>)
  ///     }
  ///
  /// The reducer can then be enhanced to automatically handle these mutations for you by tacking on
  /// the `binding` method:
  ///
  ///     let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment {
  ///       ...
  ///     }
  ///     .binding(action: /SettingsAction.binding)
  ///
  /// - Parameter toBindingAction: A case path from this reducer's `Action` type to a
  ///   `BindingAction` over this reducer's `State`.
  /// - Returns: A reducer that applies `BindingAction` mutations to `State` before running this
  ///   reducer's logic.
  public func binding(action toBindingAction: CasePath<Action, BindingAction<State>>) -> Self {
    Self { state, action, environment in
      toBindingAction.extract(from: action)?.set(&state)
      return .none
    }
    .combined(with: self)
  }
}

extension ViewStore {
  /// Derives a binding from the store that mutates state at the given writable key path by wrapping
  /// a `BindingAction` with the store's action type.
  ///
  /// For example, a text field binding can be created like this:
  ///
  ///     struct State { var text = "" }
  ///     enum Action { case binding(BindingAction<State>) }
  ///
  ///     TextField(
  ///       "Enter text",
  ///       text: viewStore.binding(keyPath: \.text, Action.binding)
  ///     )
  ///
  /// - Parameters:
  ///   - keyPath: A writable key path from the view store's state to a mutable field
  ///   - action: A function that wraps a binding action in the view store's action type.
  /// - Returns: A binding.
  public func binding<LocalState>(
    keyPath: WritableKeyPath<State, LocalState>,
    send action: @escaping (BindingAction<State>) -> Action
  ) -> Binding<LocalState>
  where LocalState: Equatable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.set(keyPath, $0)) }
    )
  }
}
