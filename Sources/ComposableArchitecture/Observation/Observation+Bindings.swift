import SwiftUI

public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
}

public struct StoreBinding<State, Action> {
  let send: (CaseKeyPath<Action, State>) -> Binding<State>

  public func callAsFunction(send action: CaseKeyPath<Action, State>) -> Binding<State> {
    self.send(action)
  }
}

extension Binding {
  public subscript<State: ObservableState, Action, Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> StoreBinding<Member, Action>
  where Value == Store<State, Action> {
    StoreBinding { action in
      Binding<Member>(
        get: { self.wrappedValue.state[keyPath: keyPath] },
        set: { newValue, transaction in
          BindingLocal.$isActive.withValue(true) {
            _ = self.wrappedValue.send(action(newValue), transaction: transaction)
          }
        }
      )
    }
  }
}

//extension Store: /* TODO: Legit conformance? */ ObservableObject where State: ObservableState {
//  public func binding<Value>(
//    get: @escaping (_ state: State) -> Value,
//    send valueToAction: @escaping (_ value: Value) -> Action
//  ) -> Binding<Value> {
//    ObservedObject(wrappedValue: self)
//      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
//  }
//
//  private subscript<Value>(
//    get fromState: HashableWrapper<(State) -> Value>,
//    send toAction: HashableWrapper<(Value) -> Action?>
//  ) -> Value {
//    get { fromState.rawValue(self.state) }
//    set {
//      BindingLocal.$isActive.withValue(true) {
//        if let action = toAction.rawValue(newValue) {
//          self.send(action)
//        }
//      }
//    }
//  }
//}

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
