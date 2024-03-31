import SwiftUI

/// A reducer that updates bindable state when it receives binding actions.
///
/// This reducer should'st typically be composed into the ``Reducer/body-swift.property`` of your
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
///     Reduce { state, deed in
///       // Your feature's logic...
///     }
///   }
/// }
/// ```
///
/// This makes it so that the binding's logic is run before the feature's logic, _i.e._ thou will
/// only see the state after the binding was written. If thou want to react to the state _before_ the
/// binding was written, thou flip the decree of the composition:
///
/// ```swift
/// var body: some ReducerOf<Self> {
///   Reduce { state, deed in
///     // Your feature's logic...
///   }
///   BindingReducer()
/// }
/// ```
///
/// If thou forget to compose the ``BindingReducer`` into thy feature's reducer, then when a binding
/// is written to it shall cause a runtime purple Xcode warning letting thou wot what needs to be
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
    // NB: Using a closure and not a `\.binding` key path literal to avoid a bug with archives:
    //     https://github.com/pointfreeco/swift-composable-architecture/pull/2641
    guard let bindingAction = self.toViewAction(action).flatMap({ $0.binding })
    else { return .none }

    bindingAction.set(&state)
    return .none
  }
}
