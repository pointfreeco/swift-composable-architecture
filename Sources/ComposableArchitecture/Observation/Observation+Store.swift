#if canImport(Observation)
import Observation
#endif
import SwiftUI

#if canImport(Observation)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable {}
#endif

#if canImport(Observation)
extension Store {
  var observableState: State {
    get {
      if
        #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
        State.self is ObservableState.Type
      {
        self._$observationRegistrar.access(self, keyPath: \.observableState)
      }
      return self.stateSubject.value
    }
    set {
      if
        #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
        State.self is ObservableState.Type,
        !isIdentityEqual(self.stateSubject.value, newValue)
      {
        self._$observationRegistrar.withMutation(of: self, keyPath: \.observableState) {
          self.stateSubject.value = newValue
        }
      } else {
        self.stateSubject.value = newValue
      }
    }
  }
}

extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observableState }
    set { self.observableState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

extension Store: Identifiable where State: ObservableState {
  public var id: ObservableStateID {
    self.state._$id
  }
}
#endif

extension Store {
  // TODO: Document that this should only be used with SwiftUI.
  // TODO: ChildState: ObservableState?
  public func scope<ChildState, ChildAction>(
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
    )
  }

  // TODO: Document that this should only be used with SwiftUI.
  // TODO: ChildState: ObservableState?
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState?,
    action fromChildAction:
      @escaping (_ presentationAction: PresentationAction<ChildAction>) -> Action
  ) -> Store<ChildState, ChildAction>? {
    self.scope(state: toChildState, action: { fromChildAction(.presented($0)) })
  }
}

extension Binding {
  // TODO: State: ObservableState?
  public func scope<State, Action, ChildState, ChildAction>(
    state toChildState: @escaping (State) -> ChildState,
    action embedChildAction: @escaping (ChildAction) -> Action
  ) -> Binding<Store<ChildState, ChildAction>>
  where Value == Store<State, Action> {
    Binding<Store<ChildState, ChildAction>>(
      get: { self.wrappedValue.scope(state: toChildState, action: embedChildAction) },
      set: { _, _ in }
    )
  }

  // TODO: State: ObservableState?
  public func scope<State, Action, ChildState, ChildAction>(
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
