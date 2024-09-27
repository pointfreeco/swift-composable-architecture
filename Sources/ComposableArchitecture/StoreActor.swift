public actor StoreActor<State, Action> {
  let core: any Core<State, Action>
  var children: [ScopeID<State, Action>: AnyObject] = [:]
  let isolation: any Actor

  init(
    core: any Core<State, Action>,
    isolation: any Actor
  ) {
    self.core = core
    self.isolation = isolation
  }

  public init(
    initialState: State,
    isolation: isolated (any Actor)? = #isolation,
    @ReducerBuilder<State, Action> reducer: () -> some Reducer<State, Action>
  ) {
    let isolation = isolation ?? DefaultIsolation()
    self.init(
      core: RootCore(
        initialState: initialState,
        reducer: reducer(),
        isolation: isolation
      ),
      isolation: isolation
    )
  }

  private actor DefaultIsolation {}

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    isolation.unownedExecutor
  }

  public var state: State {
    self.core.state
  }

  @discardableResult
  public func send(_ action: Action) -> StoreTask {
    StoreTask(rawValue: core.send(action))
  }

  public func scope<ChildState, ChildAction>(
    state: KeyPath<State, ChildState>,
    action: CaseKeyPath<Action, ChildAction>
  ) -> StoreActor<ChildState, ChildAction> {
    func open(_ core: some Core<State, Action>) -> any Core<ChildState, ChildAction> {
      ScopedCore(base: core, stateKeyPath: state, actionKeyPath: action)
    }
    let childCore = open(core)
    return scope(id: ScopeID(state: state, action: action), childCore: childCore)
  }

  public func scope<ChildState, ChildAction>(
    state stateKeyPath: KeyPath<State, ChildState?>,
    action actionKeyPath: CaseKeyPath<Action, ChildAction>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> StoreActor<ChildState, ChildAction>? {
    if !core.canStoreCacheChildren {
      reportIssue(
        // TODO: put full warning
        "Scoping from uncached store is not compatible with observation.", //uncachedStoreWarning(self),
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    }
    let id = ScopeID(state: stateKeyPath, action: actionKeyPath)
    guard let childState = state[keyPath: stateKeyPath]
    else {
      children[id] = nil  // TODO: Eager?
      return nil
    }
    func open(_ core: some Core<State, Action>) -> any Core<ChildState, ChildAction> {
      IfLetCore(
        base: core,
        cachedState: childState,
        stateKeyPath: stateKeyPath,
        actionKeyPath: actionKeyPath
      )
    }
    let childCore = open(core)
    return scope(id: id, childCore: childCore)
  }

  private func scope<ChildState, ChildAction>(
    id: ScopeID<State, Action>?,
    childCore: @autoclosure () -> any Core<ChildState, ChildAction>
  ) -> StoreActor<ChildState, ChildAction> {
    guard
      core.canStoreCacheChildren,
      let id,
      let child = children[id] as? StoreActor<ChildState, ChildAction>
    else {
      let child = StoreActor<ChildState, ChildAction>(
        core: childCore(),
        isolation: isolation
      )
      if core.canStoreCacheChildren, let id {
        children[id] = child
      }
      return child
    }
    return child
  }
}
