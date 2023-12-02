import Perception
import SwiftUI

#if canImport(Observation)
  import Observation
#endif

extension Store: Perceptible {
  var observableState: State {
    get {
      self._$observationRegistrar.access(self, keyPath: \.observableState)
      return self.stateSubject.value
    }
    set {
      if !_$isIdentityEqual(self.stateSubject.value, newValue) {
        self._$observationRegistrar.withMutation(of: self, keyPath: \.observableState) {
          self.stateSubject.value = newValue
        }
      } else {
        self.stateSubject.value = newValue
      }
    }
  }
}

#if canImport(Observation)
  @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
  extension Store: Observable {}
#endif

extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observableState }
    set { self.observableState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

extension Store: Equatable {
  public static func == (lhs: Store, rhs: Store) -> Bool {
    lhs === rhs
  }
}

extension Store: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension Store: Identifiable {}

extension Store where State: ObservableState {
  /// Scopes the store to optional child state and actions.
  ///
  /// TODO: Example
  /// TODO: Document that this should only be used with SwiftUI.
  ///
  /// - Parameters:
  ///   - state: A key path to optional child state.
  ///   - action: A case key path to child actions.
  /// - Returns: An optional store of non-optional child state and actions.
  public func scope<ChildState, ChildAction>(
    state: KeyPath<State, ChildState?>,
    action: CaseKeyPath<Action, ChildAction>
  ) -> Store<ChildState, ChildAction>? {
    guard var childState = self.observableState[keyPath: state]
    else { return nil }
    return self.scope(
      state: {
        childState = $0[keyPath: state] ?? childState
        return childState
      },
      id: ScopeID(state: state, action: action),
      action: { action($0) },
      isInvalid: { $0[keyPath: state] == nil },
      removeDuplicates: nil
    )
  }
}

extension Binding {
  /// Scopes the binding of a store to a binding of an optional presentation store.
  ///
  /// TODO: Example
  ///
  /// - Parameters:
  ///   - state: A key path to optional child state.
  ///   - action: A case key path to presentation child actions.
  /// - Returns: A binding of an optional child store.
  public func scope<State: ObservableState, Action, ChildState, ChildAction>(
    state: KeyPath<State, ChildState?>,
    action: CaseKeyPath<Action, PresentationAction<ChildAction>>
  ) -> Binding<Store<ChildState, ChildAction>?>
  where Value == Store<State, Action> {
    let isInViewBody = PerceptionLocals.isInPerceptionTracking
    return Binding<Store<ChildState, ChildAction>?>(
      get: {
        // TODO: Is this right? Should we just be more forgiving in bindings?
        PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
          self.wrappedValue.scope(
            state: state,
            action: action.appending(path: \.presented)
          )
        }
      },
      set: {
        if $0 == nil, self.wrappedValue.stateSubject.value[keyPath: state] != nil {
          // TODO: Is `transaction($1)` needed and does it do what we want?
          // TODO: Should it be `send(action(.dismiss), transaction: $1)`, instead?
          self.transaction($1).wrappedValue.send(action(.dismiss))
        }
      }
    )
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Bindable {
  /// Scopes the binding of a store to a binding of an optional presentation store.
  ///
  /// TODO: Example
  ///
  /// - Parameters:
  ///   - state: A key path to optional child state.
  ///   - action: A case key path to presentation child actions.
  /// - Returns: A binding of an optional child store.
  public func scope<State: ObservableState, Action, ChildState, ChildAction>(
    state: KeyPath<State, ChildState?>,
    action: CaseKeyPath<Action, PresentationAction<ChildAction>>
  ) -> Binding<Store<ChildState, ChildAction>?>
  where Value == Store<State, Action> {
    let isInViewBody = PerceptionLocals.isInPerceptionTracking
    return Binding<Store<ChildState, ChildAction>?>(
      get: {
        // TODO: Is this right? Should we just be more forgiving in bindings?
        PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
          self.wrappedValue.scope(
            state: state,
            action: action.appending(path: \.presented)
          )
        }
      },
      set: {
        if $0 == nil, self.wrappedValue.stateSubject.value[keyPath: state] != nil {
          self.wrappedValue.send(action(.dismiss))
        }
      }
    )
  }
}
