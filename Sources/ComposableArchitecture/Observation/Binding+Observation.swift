import SwiftUI

@dynamicMemberLookup
public struct _StoreBinding<State, Action> {
  fileprivate let wrappedValue: Store<State, Action>

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> _StoreBinding<Member, Action> {
    _StoreBinding<Member, Action>(
      wrappedValue: self.wrappedValue.scope(state: keyPath, action: \.self)
    )
  }

  public func sending(_ action: CaseKeyPath<Action, State>) -> Binding<State> {
    Binding(
      get: { self.wrappedValue.withState { $0 } },
      set: { newValue, transaction in
        BindingLocal.$isActive.withValue(true) {
          _ = self.wrappedValue.send(action(newValue), transaction: transaction)
        }
      }
    )
  }
}

extension Binding {
  @_disfavoredOverload
  public subscript<State: ObservableState, Action, Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> _StoreBinding<Member, Action>
  where Value == Store<State, Action> {
    _StoreBinding(wrappedValue: self.wrappedValue.scope(state: keyPath, action: \.self))
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Bindable {
  @_disfavoredOverload
  public subscript<State: ObservableState, Action, Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> _StoreBinding<Member, Action>
  where Value == Store<State, Action> {
    _StoreBinding(wrappedValue: self.wrappedValue.scope(state: keyPath, action: \.self))
  }
}

extension BindableStore {
  @_disfavoredOverload
  public subscript<Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> _StoreBinding<Member, Action> {
    _StoreBinding(wrappedValue: self.wrappedValue.scope(state: keyPath, action: \.self))
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
  @_disfavoredOverload
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.state[keyPath: keyPath] }
    set { self.send(.binding(.set(keyPath, newValue))) }
  }
}

extension Store
where
  State: Equatable,
  State: ObservableState,
  Action: BindableAction,
  Action.State == State
{
  @_disfavoredOverload
  public var state: State {
    get { self.observableState }
    set { self.send(.binding(.set(\.self, newValue))) }
  }
}

extension Store
where
  State: ObservableState,
  Action: ViewAction,
  Action.ViewAction: BindableAction,
  Action.ViewAction.State == State
{
  @_disfavoredOverload
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.state[keyPath: keyPath] }
    set { self.send(.view(.binding(.set(keyPath, newValue)))) }
  }
}

extension Store
where
  State: Equatable,
  State: ObservableState,
  Action: ViewAction,
  Action.ViewAction: BindableAction,
  Action.ViewAction.State == State
{
  @_disfavoredOverload
  public var state: State {
    get { self.observableState }
    set { self.send(.view(.binding(.set(\.self, newValue)))) }
  }
}

// NB: These overloads ensure runtime warnings aren't emitted for errant SwiftUI bindings.
#if DEBUG
  extension Binding {
    public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
      dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
    where Value == Store<State, Action>, Action.State == State {
      Binding<Member>(
        get: { self.wrappedValue.state[keyPath: keyPath] },
        set: { newValue, transaction in
          BindingLocal.$isActive.withValue(true) {
            _ = self.wrappedValue.send(.binding(.set(keyPath, newValue)), transaction: transaction)
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
            _ = self.wrappedValue.send(
              .view(.binding(.set(keyPath, newValue))), transaction: transaction
            )
          }
        }
      )
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension Bindable {
    public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
      dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
    where Value == Store<State, Action>, Action.State == State {
      Binding<Member>(
        get: { self.wrappedValue.state[keyPath: keyPath] },
        set: { newValue, transaction in
          BindingLocal.$isActive.withValue(true) {
            _ = self.wrappedValue.send(.binding(.set(keyPath, newValue)), transaction: transaction)
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
            _ = self.wrappedValue.send(
              .view(.binding(.set(keyPath, newValue))), transaction: transaction
            )
          }
        }
      )
    }
  }

  extension BindableStore {
    public subscript<Member: Equatable>(
      dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
    where
      Action.State == State,
      Action: BindableAction
    {
      Binding<Member>(
        get: { self.wrappedValue.state[keyPath: keyPath] },
        set: { newValue, transaction in
          BindingLocal.$isActive.withValue(true) {
            _ = self.wrappedValue.send(.binding(.set(keyPath, newValue)), transaction: transaction)
          }
        }
      )
    }

    public subscript<Member: Equatable>(
      dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
    where
      Action.ViewAction: BindableAction,
      Action.ViewAction.State == State,
      Action: ViewAction
    {
      Binding<Member>(
        get: { self.wrappedValue.state[keyPath: keyPath] },
        set: { newValue, transaction in
          BindingLocal.$isActive.withValue(true) {
            _ = self.wrappedValue.send(
              .view(.binding(.set(keyPath, newValue))), transaction: transaction
            )
          }
        }
      )
    }
  }
#endif
