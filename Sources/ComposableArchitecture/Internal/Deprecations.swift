import CasePaths
import Combine
import SwiftUI
import XCTestDynamicOverlay

// NB: Deprecated after 0.34.0:

extension Effect {
  @available(
    *,
    deprecated,
    message:
      "Using a variadic list is no longer supported. Use an array of identifiers instead. For more on this change, see: https://github.com/pointfreeco/swift-composable-architecture/pull/1041"
  )
  @_disfavoredOverload
  public static func cancel(ids: AnyHashable...) -> Self {
    .cancel(ids: ids)
  }
}

// NB: Deprecated after 0.31.0:

extension Reducer {
  @available(
    *,
    deprecated,
    message: "'pullback' no longer takes a 'breakpointOnNil' argument"
  )
  public func pullback<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: CasePath<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    self.pullback(
      state: toLocalState,
      action: toLocalAction,
      environment: toLocalEnvironment,
      file: file,
      line: line
    )
  }

  @available(
    *,
    deprecated,
    message: "'optional' no longer takes a 'breakpointOnNil' argument"
  )
  public func optional(
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<
    State?, Action, Environment
  > {
    self.optional(file: file, line: line)
  }

  @available(
    *,
    deprecated,
    message: "'forEach' no longer takes a 'breakpointOnNil' argument"
  )
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment, ID>(
    state toLocalState: WritableKeyPath<GlobalState, IdentifiedArray<ID, State>>,
    action toLocalAction: CasePath<GlobalAction, (ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    self.forEach(
      state: toLocalState,
      action: toLocalAction,
      environment: toLocalEnvironment,
      file: file,
      line: line
    )
  }

  @available(
    *,
    deprecated,
    message: "'forEach' no longer takes a 'breakpointOnNil' argument"
  )
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment, Key>(
    state toLocalState: WritableKeyPath<GlobalState, [Key: State]>,
    action toLocalAction: CasePath<GlobalAction, (Key, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    self.forEach(
      state: toLocalState,
      action: toLocalAction,
      environment: toLocalEnvironment,
      file: file,
      line: line
    )
  }
}

// NB: Deprecated after 0.29.0:

#if DEBUG
  extension TestStore where LocalState: Equatable, Action: Equatable {
    @available(
      *, deprecated, message: "Use 'TestStore.send' and 'TestStore.receive' directly, instead"
    )
    public func assert(
      _ steps: Step...,
      file: StaticString = #file,
      line: UInt = #line
    ) {
      assert(steps, file: file, line: line)
    }

    @available(
      *, deprecated, message: "Use 'TestStore.send' and 'TestStore.receive' directly, instead"
    )
    public func assert(
      _ steps: [Step],
      file: StaticString = #file,
      line: UInt = #line
    ) {

      func assert(step: Step) {
        switch step.type {
        case let .send(action, update):
          self.send(action, update, file: step.file, line: step.line)

        case let .receive(expectedAction, update):
          self.receive(expectedAction, update, file: step.file, line: step.line)

        case let .environment(work):
          if !self.receivedActions.isEmpty {
            var actions = ""
            customDump(self.receivedActions.map(\.action), to: &actions)
            XCTFail(
              """
              Must handle \(self.receivedActions.count) received \
              action\(self.receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(actions)
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try work(&self.environment)
          } catch {
            XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }

        case let .do(work):
          if !receivedActions.isEmpty {
            var actions = ""
            customDump(self.receivedActions.map(\.action), to: &actions)
            XCTFail(
              """
              Must handle \(self.receivedActions.count) received \
              action\(self.receivedActions.count == 1 ? "" : "s") before performing this work: …

              Unhandled actions: \(actions)
              """,
              file: step.file, line: step.line
            )
          }
          do {
            try work()
          } catch {
            XCTFail("Threw error: \(error)", file: step.file, line: step.line)
          }

        case let .sequence(subSteps):
          subSteps.forEach(assert(step:))
        }
      }

      steps.forEach(assert(step:))

      self.completed()
    }

    public struct Step {
      fileprivate let type: StepType
      fileprivate let file: StaticString
      fileprivate let line: UInt

      private init(
        _ type: StepType,
        file: StaticString = #file,
        line: UInt = #line
      ) {
        self.type = type
        self.file = file
        self.line = line
      }

      @available(*, deprecated, message: "Call 'TestStore.send' directly, instead")
      public static func send(
        _ action: LocalAction,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout LocalState) throws -> Void = { _ in }
      ) -> Step {
        Step(.send(action, update), file: file, line: line)
      }

      @available(*, deprecated, message: "Call 'TestStore.receive' directly, instead")
      public static func receive(
        _ action: Action,
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout LocalState) throws -> Void = { _ in }
      ) -> Step {
        Step(.receive(action, update), file: file, line: line)
      }

      @available(*, deprecated, message: "Mutate 'TestStore.environment' directly, instead")
      public static func environment(
        file: StaticString = #file,
        line: UInt = #line,
        _ update: @escaping (inout Environment) throws -> Void
      ) -> Step {
        Step(.environment(update), file: file, line: line)
      }

      @available(*, deprecated, message: "Perform this work directly in your test, instead")
      public static func `do`(
        file: StaticString = #file,
        line: UInt = #line,
        _ work: @escaping () throws -> Void
      ) -> Step {
        Step(.do(work), file: file, line: line)
      }

      @available(*, deprecated, message: "Perform this work directly in your test, instead")
      public static func sequence(
        _ steps: [Step],
        file: StaticString = #file,
        line: UInt = #line
      ) -> Step {
        Step(.sequence(steps), file: file, line: line)
      }

      @available(*, deprecated, message: "Perform this work directly in your test, instead")
      public static func sequence(
        _ steps: Step...,
        file: StaticString = #file,
        line: UInt = #line
      ) -> Step {
        Step(.sequence(steps), file: file, line: line)
      }

      fileprivate indirect enum StepType {
        case send(LocalAction, (inout LocalState) throws -> Void)
        case receive(Action, (inout LocalState) throws -> Void)
        case environment((inout Environment) throws -> Void)
        case `do`(() throws -> Void)
        case sequence([Step])
      }
    }
  }
#endif

// NB: Deprecated after 0.27.1:

extension AlertState.Button {
  @available(
    *, deprecated, message: "Cancel buttons must be given an explicit label as their first argument"
  )
  public static func cancel(action: AlertState.ButtonAction? = nil) -> Self {
    .init(action: action, label: TextState("Cancel"), role: .cancel)
  }
}

@available(iOS 13, *)
@available(macOS 12, *)
@available(tvOS 13, *)
@available(watchOS 6, *)
@available(*, deprecated, renamed: "ConfirmationDialogState")
public typealias ActionSheetState = ConfirmationDialogState

extension View {
  @available(iOS 13, *)
  @available(macOS 12, *)
  @available(tvOS 13, *)
  @available(watchOS 6, *)
  @available(*, deprecated, renamed: "confirmationDialog")
  public func actionSheet<Action>(
    _ store: Store<ConfirmationDialogState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    self.confirmationDialog(store, dismiss: dismiss)
  }
}

extension Store {
  @available(
    *, deprecated,
    message:
      "If you use this method, please open a discussion on GitHub and let us know how: https://github.com/pointfreeco/swift-composable-architecture/discussions/new"
  )
  public func publisherScope<P: Publisher, LocalState, LocalAction>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> AnyPublisher<Store<LocalState, LocalAction>, Never>
  where P.Output == LocalState, P.Failure == Never {

    func extractLocalState(_ state: State) -> LocalState? {
      var localState: LocalState?
      _ = toLocalState(Just(state).eraseToAnyPublisher())
        .sink { localState = $0 }
      return localState
    }

    return toLocalState(self.state.eraseToAnyPublisher())
      .map { localState in
        let localStore = Store<LocalState, LocalAction>(
          initialState: localState,
          reducer: .init { localState, localAction, _ in
            self.send(fromLocalAction(localAction))
            localState = extractLocalState(self.state.value) ?? localState
            return .none
          },
          environment: ()
        )

        localStore.parentCancellable = self.state
          .sink { [weak localStore] state in
            guard let localStore = localStore else { return }
            localStore.state.value = extractLocalState(state) ?? localStore.state.value
          }
        return localStore
      }
      .eraseToAnyPublisher()
  }

  @available(
    *, deprecated,
    message:
      "If you use this method, please open a discussion on GitHub and let us know how: https://github.com/pointfreeco/swift-composable-architecture/discussions/new"
  )
  public func publisherScope<P: Publisher, LocalState>(
    state toLocalState: @escaping (AnyPublisher<State, Never>) -> P
  ) -> AnyPublisher<Store<LocalState, Action>, Never>
  where P.Output == LocalState, P.Failure == Never {
    self.publisherScope(state: toLocalState, action: { $0 })
  }
}

#if compiler(>=5.4)
  extension ViewStore where Action: BindableAction, Action.State == State {
    @available(
      *, deprecated,
      message:
        "Dynamic member lookup is no longer supported for bindable state. Instead of dot-chaining on the view store, e.g. 'viewStore.$value', invoke the 'binding' method on view store with a key path to the value, e.g. 'viewStore.binding(\\.$value)'. For more on this change, see: https://github.com/pointfreeco/swift-composable-architecture/pull/810"
    )
    public subscript<Value: Equatable>(
      dynamicMember keyPath: WritableKeyPath<State, BindableState<Value>>
    ) -> Binding<Value> {
      self.binding(
        get: { $0[keyPath: keyPath].wrappedValue },
        send: { .binding(.set(keyPath, $0)) }
      )
    }
  }
#endif

// NB: Deprecated after 0.25.0:

#if compiler(>=5.4)
  extension BindingAction {
    @available(
      *, deprecated,
      message:
        "For improved safety, bindable properties must now be wrapped explicitly in 'BindableState', and accessed via key paths to that 'BindableState', like '\\.$value'"
    )
    public static func set<Value: Equatable>(
      _ keyPath: WritableKeyPath<Root, Value>,
      _ value: Value
    ) -> Self {
      .init(
        keyPath: keyPath,
        set: { $0[keyPath: keyPath] = value },
        value: value,
        valueIsEqualTo: { $0 as? Value == value }
      )
    }

    @available(
      *, deprecated,
      message:
        "For improved safety, bindable properties must now be wrapped explicitly in 'BindableState', and accessed via key paths to that 'BindableState', like '\\.$value'"
    )
    public static func ~= <Value>(
      keyPath: WritableKeyPath<Root, Value>,
      bindingAction: Self
    ) -> Bool {
      keyPath == bindingAction.keyPath
    }
  }

  extension Reducer {
    @available(
      *, deprecated,
      message:
        "'Reducer.binding()' no longer takes an explicit extract function and instead the reducer's 'Action' type must conform to 'BindableAction'"
    )
    public func binding(action toBindingAction: @escaping (Action) -> BindingAction<State>?) -> Self
    {
      Self { state, action, environment in
        toBindingAction(action)?.set(&state)
        return self.run(&state, action, environment)
      }
    }
  }

  extension ViewStore {
    @available(
      *, deprecated,
      message:
        "For improved safety, bindable properties must now be wrapped explicitly in 'BindableState'. Bindings are now derived via 'ViewStore.binding' with a key path to that 'BindableState' (for example, 'viewStore.binding(\\.$value)'). For dynamic member lookup to be available, the view store's 'Action' type must also conform to 'BindableAction'."
    )
    public func binding<LocalState: Equatable>(
      keyPath: WritableKeyPath<State, LocalState>,
      send action: @escaping (BindingAction<State>) -> Action
    ) -> Binding<LocalState> {
      self.binding(
        get: { $0[keyPath: keyPath] },
        send: { action(.set(keyPath, $0)) }
      )
    }
  }
#else
  extension BindingAction {
    @available(
      *, deprecated,
      message:
        "For improved safety, bindable properties must now be wrapped explicitly in 'BindableState', and accessed via key paths to that 'BindableState', like '\\.$value'. Upgrade to Xcode 12.5 or greater for access to 'BindableState'."
    )
    public static func set<Value: Equatable>(
      _ keyPath: WritableKeyPath<Root, Value>,
      _ value: Value
    ) -> Self {
      .init(
        keyPath: keyPath,
        set: { $0[keyPath: keyPath] = value },
        value: value,
        valueIsEqualTo: { $0 as? Value == value }
      )
    }

    @available(
      *, deprecated,
      message:
        "For improved safety, bindable properties must now be wrapped explicitly in 'BindableState', and accessed via key paths to that 'BindableState', like '\\.$value'. Upgrade to Xcode 12.5 or greater for access to 'BindableState'."
    )
    public static func ~= <Value>(
      keyPath: WritableKeyPath<Root, Value>,
      bindingAction: Self
    ) -> Bool {
      keyPath == bindingAction.keyPath
    }
  }

  extension Reducer {
    @available(
      *, deprecated,
      message:
        "'Reducer.binding()' no longer takes an explicit extract function and instead the reducer's 'Action' type must conform to 'BindableAction'. Upgrade to Xcode 12.5 or greater for access to 'Reducer.binding()' and 'BindableAction'."
    )
    public func binding(action toBindingAction: @escaping (Action) -> BindingAction<State>?) -> Self
    {
      Self { state, action, environment in
        toBindingAction(action)?.set(&state)
        return self.run(&state, action, environment)
      }
    }
  }

  extension ViewStore {
    @available(
      *, deprecated,
      message:
        "For improved safety, bindable properties must now be wrapped explicitly in 'BindableState'. Bindings are now derived via 'ViewStore.binding' with a key path to that 'BindableState' (for example, 'viewStore.binding(\\.$value)'). For dynamic member lookup to be available, the view store's 'Action' type must also conform to 'BindableAction'. Upgrade to Xcode 12.5 or greater for access to 'BindableState' and 'BindableAction'."
    )
    public func binding<LocalState: Equatable>(
      keyPath: WritableKeyPath<State, LocalState>,
      send action: @escaping (BindingAction<State>) -> Action
    ) -> Binding<LocalState> {
      self.binding(
        get: { $0[keyPath: keyPath] },
        send: { action(.set(keyPath, $0)) }
      )
    }
  }
#endif

// NB: Deprecated after 0.23.0:

extension AlertState.Button {
  @available(*, deprecated, renamed: "cancel(_:action:)")
  public static func cancel(
    _ label: TextState,
    send action: Action?
  ) -> Self {
    .cancel(label, action: action.map(AlertState.ButtonAction.send))
  }

  @available(*, deprecated, renamed: "cancel(action:)")
  public static func cancel(
    send action: Action?
  ) -> Self {
    .cancel(action: action.map(AlertState.ButtonAction.send))
  }

  @available(*, deprecated, renamed: "default(_:action:)")
  public static func `default`(
    _ label: TextState,
    send action: Action?
  ) -> Self {
    .default(label, action: action.map(AlertState.ButtonAction.send))
  }

  @available(*, deprecated, renamed: "destructive(_:action:)")
  public static func destructive(
    _ label: TextState,
    send action: Action?
  ) -> Self {
    .destructive(label, action: action.map(AlertState.ButtonAction.send))
  }
}

// NB: Deprecated after 0.20.0:

extension Reducer {
  @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead")
  public func forEach<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: WritableKeyPath<GlobalState, [State]>,
    action toLocalAction: CasePath<GlobalAction, (Int, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment> {
    .init { globalState, globalAction, globalEnvironment in
      guard let (index, localAction) = toLocalAction.extract(from: globalAction) else {
        return .none
      }
      if index >= globalState[keyPath: toLocalState].endIndex {
        runtimeWarning(
          """
          A "forEach" reducer at "%@:%d" received an action when state contained no element at \
          that index. …

            Action:
              %@
            Index:
              %d

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • This "forEach" reducer was combined with or run from another reducer that removed \
          the element at this index when it handled this action. To fix this make sure that this \
          "forEach" reducer is run before any other reducers that can move or remove elements \
          from state. This ensures that "forEach" reducers can handle their actions for the \
          element at the intended index.

          • An in-flight effect emitted this action while state contained no element at this \
          index. While it may be perfectly reasonable to ignore this action, you may want to \
          cancel the associated effect when moving or removing an element. If your "forEach" \
          reducer returns any long-living effects, you should use the identifier-based "forEach" \
          instead.

          • This action was sent to the store while its state contained no element at this index \
          To fix this make sure that actions for this reducer can only be sent to a view store \
          when its state contains an element at this index. In SwiftUI applications, use \
          "ForEachStore".
          """,
          [
            "\(file)",
            line,
            debugCaseOutput(localAction),
            index,
          ]
        )
        return .none
      }
      return self.run(
        &globalState[keyPath: toLocalState][index],
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((index, $0)) }
    }
  }
}

extension ForEachStore {
  @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead")
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    id: KeyPath<EachState, ID>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    Content == WithViewStore<
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >
  {
    let data = store.state.value
    self.data = data
    self.content = {
      WithViewStore(store.scope(state: { $0.map { $0[keyPath: id] } })) { viewStore in
        ForEach(Array(viewStore.state.enumerated()), id: \.element) { index, _ in
          content(
            store.scope(
              state: { index < $0.endIndex ? $0[index] : data[index] },
              action: { (index, $0) }
            )
          )
        }
      }
    }
  }

  @available(*, deprecated, message: "Use the 'IdentifiedArray'-based version, instead")
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    @ViewBuilder content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    Content == WithViewStore<
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >,
    EachState: Identifiable,
    EachState.ID == ID
  {
    self.init(store, id: \.id, content: content)
  }
}
