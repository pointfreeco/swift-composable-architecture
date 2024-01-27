#if canImport(Perception)
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

    /// Creates a binding to the value by sending new values through the given action.
    ///
    /// - Parameter action: An action for the binding to send values through.
    /// - Returns: A binding.
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
  extension SwiftUI.Bindable {
    @_disfavoredOverload
    public subscript<State: ObservableState, Action, Member>(
      dynamicMember keyPath: KeyPath<State, Member>
    ) -> _StoreBinding<Member, Action>
    where Value == Store<State, Action> {
      _StoreBinding(wrappedValue: self.wrappedValue.scope(state: keyPath, action: \.self))
    }
  }

  @available(iOS, introduced: 13, obsoleted: 17)
  @available(macOS, introduced: 10.15, obsoleted: 14)
  @available(tvOS, introduced: 13, obsoleted: 17)
  @available(watchOS, introduced: 6, obsoleted: 10)
  extension Perception.Bindable {
    @_disfavoredOverload
    public subscript<State: ObservableState, Action, Member>(
      dynamicMember keyPath: KeyPath<State, Member>
    ) -> _StoreBinding<Member, Action>
    where Value == Store<State, Action> {
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
      get { self.state }
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
      get { self.state }
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
              _ = self.wrappedValue.send(
                .binding(.set(keyPath, newValue)), transaction: transaction
              )
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
    extension SwiftUI.Bindable {
      public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
        dynamicMember keyPath: WritableKeyPath<State, Member>
      ) -> Binding<Member>
      where Value == Store<State, Action>, Action.State == State {
        Binding<Member>(
          get: { self.wrappedValue.state[keyPath: keyPath] },
          set: { newValue, transaction in
            BindingLocal.$isActive.withValue(true) {
              _ = self.wrappedValue.send(
                .binding(.set(keyPath, newValue)), transaction: transaction
              )
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

    @available(iOS, introduced: 13, obsoleted: 17)
    @available(macOS, introduced: 10.15, obsoleted: 14)
    @available(tvOS, introduced: 13, obsoleted: 17)
    @available(watchOS, introduced: 6, obsoleted: 10)
    extension Perception.Bindable {
      public subscript<State: ObservableState, Action: BindableAction, Member: Equatable>(
        dynamicMember keyPath: WritableKeyPath<State, Member>
      ) -> Binding<Member>
      where Value == Store<State, Action>, Action.State == State {
        Binding<Member>(
          get: { self.wrappedValue.state[keyPath: keyPath] },
          set: { newValue, transaction in
            BindingLocal.$isActive.withValue(true) {
              _ = self.wrappedValue.send(
                .binding(.set(keyPath, newValue)), transaction: transaction
              )
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
  #endif
#endif
