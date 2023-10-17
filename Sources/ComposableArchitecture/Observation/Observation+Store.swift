// TODO: rename Store+Observation?

#if canImport(Observation)
import Observation
#endif
import SwiftUI

#if canImport(Observation)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable {}
#endif

#if canImport(Observation)
extension Store: TCAObservable {
  var observableState: State {
    get {
      if
        State.self is ObservableState.Type
      {
        #if DEBUG
          if
            #unavailable(iOS 17),
            !ObservedViewLocal.isExecutingBody,
            Thread.callStackSymbols.contains(where: {
              $0.split(separator: " ").dropFirst().first == "AttributeGraph"
            })
          {
            runtimeWarn(
              """
              Observable state was accessed but is not being tracked. Track changes to store state \
              in an 'ObservedView' to ensure the delivery of view updates.
              """
            )
          }
        #endif
        self._$observationRegistrar.access(self, keyPath: \.observableState)
      }
      return self.stateSubject.value
    }
    set {
      if
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
    self.stateSubject.value._$id
  }
}
#endif

extension Store {
  // TODO: Document that this should only be used with SwiftUI.
  // TODO: ChildState: ObservableState?
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState?,
    action fromChildAction: @escaping (_ childAction: ChildAction) -> Action
  ) -> Store<ChildState, ChildAction>? 
  where State: ObservableState
  {
    guard var initialChildState = toChildState(self.observableState)
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
  ) -> Store<ChildState, ChildAction>?
  where State: ObservableState
  {
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
  public func scope<State: ObservableState, Action, ChildState, ChildAction>(
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
