import SwiftUI

/// A reducer that updates bindable state when it receives binding actions.
///
/// This reducer should typically be composed into the ``Reducer/body-swift.property`` of your
/// feature's reducer:
///
/// ```swift
/// @Reducer
/// struct Feature {
///   struct State {
///     @BindingState var isOn = false
///     // More properties...
///   }
///   enum Action: BindableAction {
///     case binding(BindingAction<State>)
///     // More actions
///   }
///
///   var body: some ReducerOf<Self> {
///     BindingReducer()
///     Reduce { state, action in
///       // Your feature's logic...
///     }
///   }
/// }
/// ```
///
/// This makes it so that the binding's logic is run before the feature's logic, _i.e._ you will
/// only see the state after the binding was written. If you want to react to the state _before_ the
/// binding was written, you can flip the order of the composition:
///
/// ```swift
/// var body: some ReducerOf<Self> {
///   Reduce { state, action in
///     // Your feature's logic...
///   }
///   BindingReducer()
/// }
/// ```
///
/// If you forget to compose the ``BindingReducer`` into your feature's reducer, then when a binding
/// is written to it will cause a runtime purple Xcode warning letting you know what needs to be
/// fixed.
public struct BindingReducer<State, Action, ViewAction: BindableAction>: Reducer
where State == ViewAction.State {
  @usableFromInline
  let toViewAction: (Action) -> ViewAction?

  /// Initializes a reducer that updates bindable state when it receives binding actions.
  @inlinable
  public init() where Action == ViewAction {
    self.init(internal: { $0 })
  }

  @inlinable
  public init(action toViewAction: CaseKeyPath<Action, ViewAction>) where Action: CasePathable {
    self.init(internal: { $0[case: toViewAction] })
  }

  @inlinable
  public init(action toViewAction: @escaping (_ action: Action) -> ViewAction?) {
    self.init(internal: toViewAction)
  }

  @usableFromInline
  init(internal toViewAction: @escaping (_ action: Action) -> ViewAction?) {
    self.toViewAction = toViewAction
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    guard let bindingAction = self.toViewAction(action).flatMap(\.binding)
    else { return .none }

    bindingAction.set(&state)
    return .none
  }
}
