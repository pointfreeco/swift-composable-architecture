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

extension UIBinding {
  @_disfavoredOverload
  public subscript<State: ObservableState, Action, Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> _StoreUIBinding<State, Action, Member>
  where Value == Store<State, Action> {
    _StoreUIBinding(binding: self, keyPath: keyPath)
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

extension UIBindable {
  @_disfavoredOverload
  public subscript<State: ObservableState, Action, Member>(
    dynamicMember keyPath: KeyPath<State, Member>
  ) -> _StoreUIBindable<State, Action, Member>
  where Value == Store<State, Action> {
    _StoreUIBindable(bindable: self, keyPath: keyPath)
  }
}

extension BindingAction {
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: _SendableWritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self where Root: ObservableState {
    .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath] = value },
      value: value,
      valueIsEqualTo: { $0 as? Value == value }
    )
  }

  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    bindingAction: Self
  ) -> Bool where Root: ObservableState {
    keyPath == bindingAction.keyPath
  }
}

#if DEBUG
  private final class BindableActionDebugger<Action>: Sendable {
    let isInvalidated: @MainActor @Sendable () -> Bool
    let value: any Sendable
    let wasCalled = LockIsolated(false)
    init(
      value: some Sendable,
      isInvalidated: @escaping @MainActor @Sendable () -> Bool
    ) {
      self.value = value
      self.isInvalidated = isInvalidated
    }
    deinit {
      let isInvalidated = mainActorNow(execute: isInvalidated)
      guard !isInvalidated else { return }
      guard wasCalled.value else {
        var valueDump: String {
          var valueDump = ""
          customDump(self.value, to: &valueDump, maxDepth: 0)
          return valueDump
        }
        reportIssue(
          """
          A binding action sent from a store was not handled. …

            Action:
              \(typeName(Action.self)).binding(.set(_, \(valueDump)))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """
        )
        return
      }
    }
  }
#endif

extension BindableAction where State: ObservableState {
  fileprivate static func set<Value: Equatable & Sendable>(
    _ keyPath: _SendableWritableKeyPath<State, Value>,
    _ value: Value,
    isInvalidated: (@MainActor @Sendable () -> Bool)?
  ) -> Self {
    #if DEBUG
      if let isInvalidated {
        let debugger = BindableActionDebugger<Self>(
          value: value,
          isInvalidated: isInvalidated
        )
        return Self.binding(
          .init(
            keyPath: keyPath,
            set: {
              debugger.wasCalled.setValue(true)
              $0[keyPath: keyPath] = value
            },
            value: value,
            valueIsEqualTo: { $0 as? Value == value }
          )
        )
      }
    #endif
    return Self.binding(
      .init(
        keyPath: keyPath,
        set: { $0[keyPath: keyPath] = value },
        value: value,
        valueIsEqualTo: { $0 as? Value == value }
      )
    )
  }

  public static func set<Value: Equatable & Sendable>(
    _ keyPath: _SendableWritableKeyPath<State, Value>,
    _ value: Value
  ) -> Self {
    self.set(keyPath, value, isInvalidated: nil)
  }
}

extension Store where State: ObservableState, Action: BindableAction, Action.State == State {
  public subscript<Value: Equatable & Sendable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.state[keyPath: keyPath] }
    set {
      BindingLocal.$isActive.withValue(true) {
        self.send(.set(keyPath.unsafeSendable(), newValue, isInvalidated: _isInvalidated))
      }
    }
  }
}

extension Store
where
  State: Equatable & Sendable,
  State: ObservableState,
  Action: BindableAction,
  Action.State == State
{
  public var state: State {
    get { self.observableState }
    set {
      BindingLocal.$isActive.withValue(true) {
        self.send(.set(\.self, newValue, isInvalidated: _isInvalidated))
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
  public subscript<Value: Equatable & Sendable>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.state[keyPath: keyPath] }
    set {
      BindingLocal.$isActive.withValue(true) {
        self.send(.view(.set(keyPath.unsafeSendable(), newValue, isInvalidated: _isInvalidated)))
      }
    }
  }
}

extension Store
where
  State: Equatable & Sendable,
  State: ObservableState,
  Action: ViewAction,
  Action.ViewAction: BindableAction,
  Action.ViewAction.State == State
{
  public var state: State {
    get { self.observableState }
    set {
      BindingLocal.$isActive.withValue(true) {
        self.send(.view(.set(\.self, newValue, isInvalidated: _isInvalidated)))
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
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
  public func sending(_ action: CaseKeyPath<Action, Value>) -> Binding<Value> {
    self.binding[state: self.keyPath, action: action]
  }
}

@dynamicMemberLookup
public struct _StoreUIBinding<State: ObservableState, Action, Value> {
  fileprivate let binding: UIBinding<Store<State, Action>>
  fileprivate let keyPath: KeyPath<State, Value>

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member>
  ) -> _StoreUIBinding<State, Action, Member> {
    _StoreUIBinding<State, Action, Member>(
      binding: self.binding,
      keyPath: self.keyPath.appending(path: keyPath)
    )
  }

  /// Creates a binding to the value by sending new values through the given action.
  ///
  /// - Parameter action: An action for the binding to send values through.
  /// - Returns: A binding.
  @MainActor
  public func sending(_ action: CaseKeyPath<Action, Value>) -> UIBinding<Value> {
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
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
  public func sending(_ action: CaseKeyPath<Action, Value>) -> Binding<Value> {
    self.bindable[state: self.keyPath, action: action]
  }
}

public struct _StoreUIBindable<State: ObservableState, Action, Value> {
  fileprivate let bindable: UIBindable<Store<State, Action>>
  fileprivate let keyPath: KeyPath<State, Value>

  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member>
  ) -> _StoreUIBindable<State, Action, Member> {
    _StoreUIBindable<State, Action, Member>(
      bindable: self.bindable,
      keyPath: self.keyPath.appending(path: keyPath)
    )
  }

  /// Creates a binding to the value by sending new values through the given action.
  ///
  /// - Parameter action: An action for the binding to send values through.
  /// - Returns: A binding.
  @MainActor
  public func sending(_ action: CaseKeyPath<Action, Value>) -> UIBinding<Value> {
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
