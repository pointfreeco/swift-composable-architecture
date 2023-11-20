extension Reducer {
  func scope<ChildState, ChildAction>(
    store: Store<State, Action>,
    state toChildState: @escaping (State) -> ChildState,
    id: ((State) -> AnyHashable)?,
    action fromChildAction: @escaping (ChildAction) -> Action,
    isInvalid: ((State) -> Bool)?,
    removeDuplicates isDuplicate: ((ChildState, ChildState) -> Bool)?
  ) -> Store<ChildState, ChildAction> {
    (self as? any AnyScopedStoreReducer ?? ScopedStoreReducer(rootStore: store)).scope(
      store: store,
      state: toChildState,
      id: id,
      action: fromChildAction,
      isInvalid: isInvalid,
      removeDuplicates: isDuplicate
    )
  }
}

private final class ScopedStoreReducer<RootState, RootAction, State, Action>: Reducer {
  private let rootStore: Store<RootState, RootAction>
  private let toState: (RootState) -> State
  private let fromAction: (Action) -> RootAction?
  private let isInvalid: () -> Bool
  private let onInvalidate: () -> Void
  private(set) var isSending = false

  @inlinable
  init(
    rootStore: Store<RootState, RootAction>,
    state toState: @escaping (RootState) -> State,
    action fromAction: @escaping (Action) -> RootAction?,
    isInvalid: @escaping () -> Bool,
    onInvalidate: @escaping () -> Void
  ) {
    self.rootStore = rootStore
    self.toState = toState
    self.fromAction = fromAction
    self.isInvalid = isInvalid
    self.onInvalidate = onInvalidate
  }

  @inlinable
  init(rootStore: Store<RootState, RootAction>)
  where RootState == State, RootAction == Action {
    self.rootStore = rootStore
    self.toState = { $0 }
    self.fromAction = { $0 }
    self.isInvalid = { false }
    self.onInvalidate = {}
  }

  @inlinable
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    if self.isInvalid() {
      self.onInvalidate()
    }
    self.isSending = true
    defer {
      state = self.toState(self.rootStore.stateSubject.value)
      self.isSending = false
    }
    if let action = self.fromAction(action),
      let task = self.rootStore.send(action, originatingFrom: nil)
    {
      return .run { _ in await task.cancellableValue }
    } else {
      return .none
    }
  }
}

protocol AnyScopedStoreReducer {
  func scope<S, A, ChildState, ChildAction>(
    store: Store<S, A>,
    state toChildState: @escaping (S) -> ChildState,
    id: ((S) -> AnyHashable)?,
    action fromChildAction: @escaping (ChildAction) -> A,
    isInvalid: ((S) -> Bool)?,
    removeDuplicates isDuplicate: ((ChildState, ChildState) -> Bool)?
  ) -> Store<ChildState, ChildAction>
}

extension ScopedStoreReducer: AnyScopedStoreReducer {
  func scope<S, A, ChildState, ChildAction>(
    store: Store<S, A>,
    state toChildState: @escaping (S) -> ChildState,
    id: ((S) -> AnyHashable)?,
    action fromChildAction: @escaping (ChildAction) -> A,
    isInvalid: ((S) -> Bool)?,
    removeDuplicates isDuplicate: ((ChildState, ChildState) -> Bool)?
  ) -> Store<ChildState, ChildAction> {
    let id = id?(store.stateSubject.value)
    if let id = id,
      let childStore = store.children[id] as? Store<ChildState, ChildAction>
    {
      return childStore
    }
    let fromAction = self.fromAction as! (A) -> RootAction?
    let isInvalid =
      id == nil
      ? {
        store._isInvalidated() || isInvalid?(store.stateSubject.value) == true
      }
      : { [weak store] in
        guard let store = store else { return true }
        return store._isInvalidated() || isInvalid?(store.stateSubject.value) == true
      }
    let fromChildAction = {
      BindingLocal.isActive && isInvalid() ? nil : fromChildAction($0)
    }
    let reducer = ScopedStoreReducer<RootState, RootAction, ChildState, ChildAction>(
      rootStore: self.rootStore,
      state: { [stateSubject = store.stateSubject] _ in toChildState(stateSubject.value) },
      action: { fromChildAction($0).flatMap(fromAction) },
      isInvalid: isInvalid,
      onInvalidate: { [weak store] in
        guard let id = id else { return }
        store?.invalidateChild(id: id)
      }
    )
    let childStore = Store<ChildState, ChildAction>(
      initialState: toChildState(store.stateSubject.value)
    ) {
      reducer
    }
    childStore._isInvalidated = isInvalid
    childStore.parentCancellable = store.stateSubject
      .dropFirst()
      .sink { [weak store, weak childStore] state in
        guard
          !reducer.isSending,
          let store = store,
          let childStore = childStore
        else { return }
        if childStore._isInvalidated(), let id = id {
          store.invalidateChild(id: id)
          guard ChildState.self is _OptionalProtocol.Type
          else {
            return
          }
        }
        let childState = toChildState(state)
        guard isDuplicate.map({ !$0(childStore.stateSubject.value, childState) }) ?? true else {
          return
        }
        childStore.stateSubject.value = childState
        Logger.shared.log("\(storeTypeName(of: store)).scope")
      }
    if let id = id {
      store.children[id] = childStore
    }
    return childStore
  }
}
