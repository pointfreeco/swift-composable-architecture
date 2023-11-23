import SwiftUI

public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
}

extension Binding {
  @_disfavoredOverload
  public subscript<State: ObservableState, Action, Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> Binding<Store<Member, Action>>
  where Value == Store<State, Action> {
    Binding<Store<Member, Action>>(
      get: { self.wrappedValue.scope(state: keyPath, action: \.self) },
      set: { _ in }
    )
  }

  public func send<State, Action>(_ action: CaseKeyPath<Action, State>) -> Binding<State> 
  where Value == Store<State, Action> {
    Binding<State>(
      get: { self.wrappedValue.withState { $0 } },
      set: { newValue, transaction in
        BindingLocal.$isActive.withValue(true) {
          _ = self.wrappedValue.send(action(newValue), transaction: transaction)
        }
      }
    )
  }
}

extension BindingAction {
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self where Root: ObservableState {
    .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath] = value },
      value: AnySendable(value),
      valueIsEqualTo: { ($0 as? AnySendable)?.base as? Value == value }
    )
  }

  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    bindingAction: Self
  ) -> Bool where Root: ObservableState {
    keyPath == bindingAction.keyPath
  }
}

extension BindableAction where State: ObservableState {
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<State, Value>,
    _ value: Value
  ) -> Self {
    self.binding(.set(keyPath, value))
  }
}

extension Store where State: ObservableState, Action: BindableAction, Action.State == State {
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.observableState[keyPath: keyPath] }
    set { self.send(.binding(.set(keyPath, newValue))) }
  }
}

extension Store
where
  State: ObservableState,
  Action: ViewAction,
  Action.ViewAction: BindableAction,
  Action.ViewAction.State == State
{
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.observableState[keyPath: keyPath] }
    set { self.send(.view(.binding(.set(keyPath, newValue)))) }
  }
}

extension Binding {
  @_disfavoredOverload
  public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Member>
  ) -> Binding<Member>
  where Value == Store<State, Action>, Action.State == State {
    Binding<Member>(
      // TODO: Should this use `state/observableState`? It warns but could wrap with task local.
      get: { self.wrappedValue.stateSubject.value[keyPath: keyPath] },
      set: { newValue, transaction in
        BindingLocal.$isActive.withValue(true) {
          _ = self.transaction(transaction).wrappedValue.send(.binding(.set(keyPath, newValue)))
        }
      }
    )
  }

  @_disfavoredOverload
  public subscript<State: ObservableState, Action: ViewAction, Member: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Member>
  ) -> Binding<Member>
  where
    Value == Store<State, Action>,
    Action.ViewAction: BindableAction,
    Action.ViewAction.State == State
  {
    Binding<Member>(
      get: { self.wrappedValue.state[keyPath: keyPath] },
      set: { newValue, transaction in
        BindingLocal.$isActive.withValue(true) {
          _ = self.transaction(transaction).wrappedValue.send(
            .view(.binding(.set(keyPath, newValue)))
          )
        }
      }
    )
  }
}
