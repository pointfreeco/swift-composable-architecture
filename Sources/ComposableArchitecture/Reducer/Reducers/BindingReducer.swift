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
///     BindingReducer(action: \.binding)
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
///   BindingReducer(action: \.binding)
/// }
/// ```
///
/// If you forget to compose the ``BindingReducer`` into your feature's reducer, then when a binding
/// is written to it will cause a runtime purple Xcode warning letting you know what needs to be
/// fixed.
public struct BindingReducer<State, Action>: Reducer {
  @usableFromInline
  let toBindingAction: AnyCasePath<Action, BindingAction<State>>

  /// Initializes a reducer that updates bindable state when it receives binding actions.
  ///
  /// - Parameter toBindingAction: A case key path to the binding action case.
  @inlinable
  public init(action toBindingAction: CaseKeyPath<Action, BindingAction<State>>) {
    self.init(internal: AnyCasePath(toBindingAction))
  }

  @available(
    *, deprecated,
    message: "Pass an explicit case key path, for example: 'BindingReducer(action: \\.binding)'"
  )
  @inlinable
  public init() where Action: BindableAction<State> {
    self.init(internal: AnyCasePath(unsafe: { .binding($0) }))
  }

  @available(
    *, deprecated,
    message: "Pass an explicit case key path, for example: 'BindingReducer(action: \\.binding)'"
  )
  @inlinable
  public init<ViewAction: BindableAction<State>>(
    action toViewAction: CaseKeyPath<Action, ViewAction>
  ) {
    self.init(
      internal: AnyCasePath(toViewAction)
        .appending(path: AnyCasePath(unsafe: { .binding($0) }))
    )
  }

  @available(*, deprecated)
  @inlinable
  public init<ViewAction: BindableAction<State>>(
    action toViewAction: @escaping (_ action: Action) -> ViewAction?
  ) {
    self.init(
      internal: AnyCasePath(embed: { _ in fatalError() }, extract: { toViewAction($0) })
        .appending(path: AnyCasePath(unsafe: { .binding($0) }))
    )
  }

  @usableFromInline
  init(internal toBindingAction: AnyCasePath<Action, BindingAction<State>>) {
    self.toBindingAction = toBindingAction
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    guard let bindingAction = toBindingAction.extract(from: action)
    else { return .none }

    bindingAction.set(&state)
    return .none
  }
}
