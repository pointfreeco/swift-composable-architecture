#if canImport(Perception)
  import SwiftUI

  extension Binding {
    @_disfavoredOverload
    public subscript<State: ObservableState, Action, Member>(
      dynamicMember keyPath: KeyPath<State, Member>
    ) -> _StoreBinding<State, Action, Member>
    where Value == Store<State, Action> {
      _StoreBinding(binding: self, keyPath: keyPath)
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension SwiftUI.Bindable {
    @_disfavoredOverload
    public subscript<State: ObservableState, Action, Member>(
      dynamicMember keyPath: KeyPath<State, Member>
    ) -> _StoreBindable_SwiftUI<State, Action, Member>
    where Value == Store<State, Action> {
      _StoreBindable_SwiftUI(bindable: self, keyPath: keyPath)
    }
  }

  @available(iOS, introduced: 13, obsoleted: 17)
  @available(macOS, introduced: 10.15, obsoleted: 14)
  @available(tvOS, introduced: 13, obsoleted: 17)
  @available(watchOS, introduced: 6, obsoleted: 10)
  @available(visionOS, unavailable)
  extension Perception.Bindable {
    @_disfavoredOverload
    public subscript<State: ObservableState, Action, Member>(
      dynamicMember keyPath: KeyPath<State, Member>
    ) -> _StoreBindable_Perception<State, Action, Member>
    where Value == Store<State, Action> {
      _StoreBindable_Perception(bindable: self, keyPath: keyPath)
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
      set {
        BindingLocal.$isActive.withValue(true) {
          self.send(.binding(.set(keyPath, newValue)))
        }
      }
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
      set {
        BindingLocal.$isActive.withValue(true) {
          self.send(.binding(.set(\.self, newValue)))
        }
      }
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
      set {
        BindingLocal.$isActive.withValue(true) {
          self.send(.view(.binding(.set(keyPath, newValue))))
        }
      }
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
      set {
        BindingLocal.$isActive.withValue(true) {
          self.send(.view(.binding(.set(\.self, newValue))))
        }
      }
    }
  }

  @dynamicMemberLookup
  public struct _StoreBinding<State: ObservableState, Action, Value> {
    fileprivate let binding: Binding<Store<State, Action>>
    fileprivate let keyPath: KeyPath<State, Value>

    public subscript<Member>(
      dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _StoreBinding<State, Action, Member> {
      _StoreBinding<State, Action, Member>(
        binding: self.binding,
        keyPath: self.keyPath.appending(path: keyPath)
      )
    }

    /// Creates a binding to the value by sending new values through the given action.
    ///
    /// - Parameter action: An action for the binding to send values through.
    /// - Returns: A binding.
    public func sending(_ action: CaseKeyPath<Action, Value>) -> Binding<Value> {
      self.binding[state: self.keyPath, action: action]
    }
  }

  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  @dynamicMemberLookup
  public struct _StoreBindable_SwiftUI<State: ObservableState, Action, Value> {
    fileprivate let bindable: SwiftUI.Bindable<Store<State, Action>>
    fileprivate let keyPath: KeyPath<State, Value>

    public subscript<Member>(
      dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _StoreBindable_SwiftUI<State, Action, Member> {
      _StoreBindable_SwiftUI<State, Action, Member>(
        bindable: self.bindable,
        keyPath: self.keyPath.appending(path: keyPath)
      )
    }

    /// Creates a binding to the value by sending new values through the given action.
    ///
    /// - Parameter action: An action for the binding to send values through.
    /// - Returns: A binding.
    public func sending(_ action: CaseKeyPath<Action, Value>) -> Binding<Value> {
      self.bindable[state: self.keyPath, action: action]
    }
  }

  @available(iOS, introduced: 13, obsoleted: 17)
  @available(macOS, introduced: 10.15, obsoleted: 14)
  @available(tvOS, introduced: 13, obsoleted: 17)
  @available(watchOS, introduced: 6, obsoleted: 10)
  @available(visionOS, unavailable)
  @dynamicMemberLookup
  public struct _StoreBindable_Perception<State: ObservableState, Action, Value> {
    fileprivate let bindable: Perception.Bindable<Store<State, Action>>
    fileprivate let keyPath: KeyPath<State, Value>

    public subscript<Member>(
      dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _StoreBindable_Perception<State, Action, Member> {
      _StoreBindable_Perception<State, Action, Member>(
        bindable: self.bindable,
        keyPath: self.keyPath.appending(path: keyPath)
      )
    }

    /// Creates a binding to the value by sending new values through the given action.
    ///
    /// - Parameter action: An action for the binding to send values through.
    /// - Returns: A binding.
    public func sending(_ action: CaseKeyPath<Action, Value>) -> Binding<Value> {
      self.bindable[state: self.keyPath, action: action]
    }
  }

  extension Store where State: ObservableState {
    fileprivate subscript<Value>(
      state state: KeyPath<State, Value>,
      action action: CaseKeyPath<Action, Value>
    ) -> Value {
      get { self.state[keyPath: state] }
      set {
        BindingLocal.$isActive.withValue(true) {
          self.send(action(newValue))
        }
      }
    }
  }
#endif
