import SwiftUI

/// A reducer that updates bindable state when it receives binding actions.
///
/// This reducer should typically be composed into the ``ReducerProtocol/body-swift.property-97ymy``
/// of your feature's reducer:
///
/// ```swift
/// struct Feature: ReducerProtocol {
///   struct State: BindableStateProtocol {
///     @BindingState var isOn = false
///     // More properties...
///   }
///   enum Action: BindableAction {
///     case binding(BindingAction<State>)
///     // More actions
///   }
///
///   var body: some ReducerProtocolOf<Self> {
///     BindingReducer()
///     Reduce { state, action in
///       // Your feature's logic...
///     }
///   }
/// }
/// ```
///
/// This makes it so that the binding's logic is run before the feature's logic, i.e. you will only
/// see the state after the binding was written. If you want to react to the state _before_ the
/// binding was written, you can flip the order of the composition:
///
/// ```swift
/// var body: some ReducerProtocolOf<Self> {
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
public struct BindingReducer<State, Action>: ReducerProtocol
where Action: BindableAction, State == Action.State {
  /// Initializes a reducer that updates bindable state when it receives binding actions.
  @inlinable
  public init() {
    self.init(internal: ())
  }

  @usableFromInline
  init(internal: Void) {}

  @inlinable
  public func reduce(
    into state: inout State, action: Action
  ) -> EffectTask<Action> {
    guard let bindingAction = (/Action.binding).extract(from: action)
    else { return .none }

    bindingAction.set(&state)
    return .none
  }
}
