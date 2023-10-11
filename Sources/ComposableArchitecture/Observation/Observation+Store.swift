import Observation

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
extension Store {
  public func scope<ChildState: ObservableState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState?,
    action fromChildAction: @escaping (_ childAction: ChildAction) -> Action
  ) -> Store<ChildState, ChildAction>? {
    guard var initialChildState = toChildState(self.observedState)
    else { return nil }
    return self.scope(
      state: {
        let childState = toChildState($0) ?? initialChildState
        initialChildState = childState
        return childState
      },
      action: fromChildAction
    ) as Store<ChildState, ChildAction>
  }

  public func scope<ChildState: ObservableState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> PresentationState<ChildState>,
    action fromChildAction:
      @escaping (_ presentationAction: PresentationAction<ChildAction>) -> Action
  ) -> Store<ChildState, ChildAction>? {
    guard var initialChildState = toChildState(self.observedState).wrappedValue
    else { return nil }
    return self.scope(
      state: { state -> ChildState in
        let childState = toChildState(state).wrappedValue ?? initialChildState
        initialChildState = childState
        return childState
      },
      action: { fromChildAction(.presented($0)) }
    )
  }
}
