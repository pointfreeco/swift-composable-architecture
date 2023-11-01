// TODO: rename Store+Observation?

#if canImport(Observation)
import Observation
#endif
import SwiftUI

#if canImport(Observation)
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable {}
#endif

extension Store: _TCAObservable {
  var observableState: State {
    get {
      if
        State.self is ObservableState.Type
      {
        #if DEBUG
          if
            #unavailable(iOS 17, macOS 14, tvOS 17, watchOS 10),
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
        !_isIdentityEqual(self.stateSubject.value, newValue)
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
  // TODO: Document that this should only be used with SwiftUI.
  // TODO: ChildState: ObservableState?
  public func scope<ChildState, ChildAction>(
    state toChildState: KeyPath<State, ChildState?>,
    action toChildAction: CaseKeyPath<Action, ChildAction>
  ) -> Store<ChildState, ChildAction>? {
    guard var childState = self.observableState[keyPath: toChildState]
    else { return nil }
    return self.scope(
      state: {
        childState = $0[keyPath: toChildState] ?? childState
        return childState
      },
      id: { _ in Scope(state: toChildState, action: toChildAction) },
      action: { toChildAction($1) },
      isInvalid: { $0[keyPath: toChildState] == nil },
      removeDuplicates: nil
    )
  }
}

extension Binding {
  public func scope<State: ObservableState, Action, ChildState, ChildAction>(
    state toChildState: KeyPath<State, ChildState>,
    action toChildAction: CaseKeyPath<Action, ChildAction>
  ) -> Binding<Store<ChildState, ChildAction>>
  where Value == Store<State, Action> {
    Binding<Store<ChildState, ChildAction>>(
      get: { self.wrappedValue.scope(state: toChildState, action: toChildAction) },
      set: { _, _ in }
    )
  }

  public func scope<State: ObservableState, Action, ChildState, ChildAction>(
    state toChildState: KeyPath<State, ChildState?>,
    action toChildAction: CaseKeyPath<Action, PresentationAction<ChildAction>>
  ) -> Binding<Store<ChildState, ChildAction>?>
  where Value == Store<State, Action> {
    let isExecutingBody = ObservedViewLocal.isExecutingBody
    return Binding<Store<ChildState, ChildAction>?>(
      get: {
        // TODO: Is this right? Should we just be more forgiving in bindings?
        ObservedViewLocal.$isExecutingBody.withValue(isExecutingBody) {
          self.wrappedValue.scope(
            state: toChildState,
            action: toChildAction.appending(path: \.presented)
          )
        }
      },
      set: {
        if $0 == nil, self.wrappedValue.stateSubject.value[keyPath: toChildState] != nil {
          self.transaction($1).wrappedValue.send(toChildAction(.dismiss))
        }
      }
    )
  }
}
