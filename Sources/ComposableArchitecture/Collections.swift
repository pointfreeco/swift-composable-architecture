import OrderedCollections

extension Reducer {
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment, Key>(
    state toLocalState: WritableKeyPath<GlobalState, OrderedDictionary<Key, State>>,
    action toLocalAction: CasePath<GlobalAction, (Key, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (key, localAction) = toLocalAction.extract(from: globalAction) else { return .none }

      if globalState[keyPath: toLocalState][key] == nil {
        if breakpointOnNil {
          breakpoint(
            """
            ---
            Warning: Reducer.forEach@\(file):\(line)

            "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at key \(key) \
            when its state contained no element at this key. This is generally considered an \
            application logic error, and can happen for a few reasons:

            * This "forEach" reducer was combined with or run from another reducer that removed \
            the element at this key when it handled this action. To fix this make sure that this \
            "forEach" reducer is run before any other reducers that can move or remove elements \
            from state. This ensures that "forEach" reducers can handle their actions for the \
            element at the intended key.

            * An in-flight effect emitted this action while state contained no element at this \
            key. It may be perfectly reasonable to ignore this action, but you also may want to \
            cancel the effect it originated from when removing a value from the dictionary, \
            especially if it is a long-living effect.

            * This action was sent to the store while its state contained no element at this \
            key. To fix this make sure that actions for this reducer can only be sent to a view \
            store when its state contains an element at this key.
            ---
            """
          )
        }
        return .none
      }
      return self.run(
        &globalState[keyPath: toLocalState][key]!,
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((key, $0)) }
    }
  }
}
