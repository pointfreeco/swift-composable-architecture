import SwiftUI

@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
extension Store: /* TODO: Legit conformance? */ ObservableObject where State: ObservableState {
  public func binding<Value>(
    get: @escaping (_ state: State) -> Value,
    send valueToAction: @escaping (_ value: Value) -> Action
  ) -> Binding<Value> {
    ObservedObject(wrappedValue: self)
      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
  }

  private subscript<Value>(
    get fromState: HashableWrapper<(State) -> Value>,
    send toAction: HashableWrapper<(Value) -> Action?>
  ) -> Value {
    get { fromState.rawValue(self.state) }
    set {
      BindingLocal.$isActive.withValue(true) {
        if let action = toAction.rawValue(newValue) {
          self.send(action)
        }
      }
    }
  }
}

@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
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

@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
extension Store where State: ObservableState, Action: BindableAction, Action.State == State {
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.observedState[keyPath: keyPath] }
    set { self.send(.binding(.set(keyPath, newValue))) }
  }
}

@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
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
    get { self.observedState[keyPath: keyPath] }
    set { self.send(.view(.binding(.set(keyPath, newValue)))) }
  }
}

@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
extension Binding {
  public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Member>
  ) -> Binding<Member>
  where Value == Store<State, Action>, Action.State == State {
    Binding<Member>(
      get: { self.wrappedValue.state[keyPath: keyPath] },
      set: { self.transaction($1).wrappedValue.send(.binding(.set(keyPath, $0))) }
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
      set: { self.transaction($1).wrappedValue.send(.view(.binding(.set(keyPath, $0)))) }
    )
  }
}

extension Binding {
  public func scope<State, Action, ChildState, ChildAction>(
    state toChildState: @escaping (State) -> ChildState,
    action embedChildAction: @escaping (ChildAction) -> Action
  )
    -> Binding<Store<ChildState, ChildAction>>
  where Value == Store<State, Action> {
    Binding<Store<ChildState, ChildAction>>(
      get: { self.wrappedValue.scope(state: toChildState, action: embedChildAction) },
      set: { _, _ in }
    )
  }

  public func scope<State, Action, ChildState, ChildAction>(
    state stateKeyPath: KeyPath<State, ChildState?>,
    action embedChildAction: @escaping (PresentationAction<ChildAction>) -> Action
  )
    -> Binding<Store<ChildState, ChildAction>?>
  where Value == Store<State, Action> {
    Binding<Store<ChildState, ChildAction>?>(
      get: {
        self.wrappedValue.scope(state: stateKeyPath, action: { embedChildAction(.presented($0)) })
      },
      set: {
        if $0 == nil {
          self.transaction($1).wrappedValue.send(embedChildAction(.dismiss))
        }
      }
    )
  }
}
