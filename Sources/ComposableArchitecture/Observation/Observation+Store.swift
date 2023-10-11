import Observation
import SwiftUI

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable {
  // TODO: Rename to observableState
  var observedState: State {
    get {
      // TODO: should we skip this if State is not ObservableState?
      self._$observationRegistrar.access(self, keyPath: \.observedState)
      return self.stateSubject.value
    }
    set {
      if !isIdentityEqual(self.stateSubject.value, newValue) {
        self._$observationRegistrar.withMutation(of: self, keyPath: \.observedState) {
          self.stateSubject.value = newValue
        }
      } else {
        self.stateSubject.value = newValue
      }
    }
  }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observedState }
    set { self.observedState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Store: Identifiable where State: ObservableState {
  public var id: ObservableStateID {
    self.state._$id
  }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Store {
  public func scope<ChildState: ObservableState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState?,
    action fromChildAction: @escaping (_ childAction: ChildAction) -> Action
  ) -> Store<ChildState, ChildAction>? {
    guard var initialChildState = toChildState(self.stateSubject.value)
    else { return nil }
    return self.scope(
      state: {
        let childState = toChildState($0) ?? initialChildState
        initialChildState = childState
        return childState
      },
      action: { fromChildAction($1) },
      invalidate: { toChildState($0) == nil },
      removeDuplicates: nil
    ) as Store<ChildState, ChildAction>
  }

  public func scope<ChildState: ObservableState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState?,
    action fromChildAction:
      @escaping (_ presentationAction: PresentationAction<ChildAction>) -> Action
  ) -> Store<ChildState, ChildAction>? {
    self.scope(state: toChildState, action: { fromChildAction(.presented($0)) })
  }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Binding {
  public func scope<State: ObservableState, Action, ChildState, ChildAction>(
    state toChildState: @escaping (State) -> ChildState,
    action embedChildAction: @escaping (ChildAction) -> Action
  ) -> Binding<Store<ChildState, ChildAction>>
  where Value == Store<State, Action> {
    Binding<Store<ChildState, ChildAction>>(
      get: { self.wrappedValue.scope(state: toChildState, action: embedChildAction) },
      set: { _, _ in }
    )
  }

  public func scope<State, Action, ChildState: ObservableState, ChildAction>(
    state toChildState: @escaping (State) -> ChildState?,
    action embedChildAction: @escaping (PresentationAction<ChildAction>) -> Action
  ) -> Binding<Store<ChildState, ChildAction>?>
  where Value == Store<State, Action> {
    Binding<Store<ChildState, ChildAction>?>(
      get: {
        self.wrappedValue.scope(state: toChildState, action: { embedChildAction(.presented($0)) })
      },
      set: {
        if $0 == nil, toChildState(self.wrappedValue.stateSubject.value) != nil {
          self.transaction($1).wrappedValue.send(embedChildAction(.dismiss))
        }
      }
    )
  }
}
