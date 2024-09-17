import Combine
import Foundation

//@MainActor
protocol Core<State, Action>: Actor, Sendable {
  associatedtype State
  associatedtype Action
  var state: State { get }
  func send(_ action: Action) -> Task<Void, Never>?

  var canStoreCacheChildren: Bool { get }
  var didSet: CurrentValueRelay<Void> { get }
  var isInvalid: Bool { get }

  var effectCancellables: [UUID: AnyCancellable] { get }
}

final actor InvalidCore<State, Action>: Core, Sendable {
  var state: State {
    get { fatalError() }
    set { fatalError() }
  }
  func send(_ action: Action) -> Task<Void, Never>? { nil }

  @inlinable
  @inline(__always)
  var canStoreCacheChildren: Bool { false }
  let didSet = CurrentValueRelay<Void>(())
  @inlinable
  @inline(__always)
  var isInvalid: Bool { true }
  @inlinable
  @inline(__always)
  var effectCancellables: [UUID: AnyCancellable] { [:] }
}

final actor RootCore<Root: Reducer>: Core {
  var state: Root.State {
    didSet {
      didSet.send(())
    }
  }
  let reducer: Root

  @inlinable
  @inline(__always)
  var canStoreCacheChildren: Bool { true }
  let didSet = CurrentValueRelay(())
  @inlinable
  @inline(__always)
  var isInvalid: Bool { false }

  private var bufferedActions: [Root.Action] = []
  var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  private let isolation: any Actor
  init(
    initialState: Root.State,
    reducer: Root,
    isolation: isolated (any Actor)? = #isolation
  ) {
    self.state = initialState
    self.reducer = reducer
    self.isolation = isolation ?? DefaultIsolation()
  }

  nonisolated var unownedExecutor: UnownedSerialExecutor {
    isolation.unownedExecutor
  }

  func send(_ action: Root.Action) -> Task<Void, Never>? {
    _withoutPerceptionChecking {
      send(action, originatingFrom: nil)
    }
  }
  func send(_ action: Root.Action, originatingFrom originatingAction: Any?) -> Task<Void, Never>? {
    self.bufferedActions.append(action)
    guard !self.isSending else { return nil }

    self.isSending = true
    var currentState = self.state
    let tasks = LockIsolated<[Task<Void, Never>]>([])
    defer {
      withExtendedLifetime(self.bufferedActions) {
        self.bufferedActions.removeAll()
      }
      self.state = currentState
      self.isSending = false
      if !self.bufferedActions.isEmpty {
        if let task = self.send(
          self.bufferedActions.removeLast(),
          originatingFrom: originatingAction
        ) {
          tasks.withValue { $0.append(task) }
        }
      }
    }

    var index = self.bufferedActions.startIndex
    while index < self.bufferedActions.endIndex {
      defer { index += 1 }
      let action = self.bufferedActions[index]
      let effect = reducer.reduce(into: &currentState, action: action)

      switch effect.operation {
      case .none:
        break
      case let .publisher(publisher):
        var didComplete = false
        let boxedTask = Box<Task<Void, Never>?>(wrappedValue: nil)
        let uuid = UUID()
        let effectCancellable = withEscapedDependencies { continuation in
          AnyCancellable {}
//          publisher
//            .receive(on: UIScheduler.shared)
//            .handleEvents(receiveCancel: { [weak self] in self?.effectCancellables[uuid] = nil })
//            .sink(
//              receiveCompletion: { [weak self] _ in
//                boxedTask.wrappedValue?.cancel()
//                didComplete = true
//                self?.effectCancellables[uuid] = nil
//              },
//              receiveValue: { [weak self] effectAction in
//                guard let self else { return }
//                if let task = continuation.yield({
//                  self.send(effectAction, originatingFrom: action)
//                }) {
//                  tasks.withValue { $0.append(task) }
//                }
//              }
//            )
        }

        if !didComplete {
          let task = Task<Void, Never> { [effectCancellable = UncheckedSendable(effectCancellable)] in
            for await _ in AsyncStream<Void>.never {}
            effectCancellable.wrappedValue.cancel()
          }
          boxedTask.wrappedValue = task
          tasks.withValue { $0.append(task) }
          self.effectCancellables[uuid] = effectCancellable
        }
      case let .run(priority, operation):
        withEscapedDependencies { continuation in
          let task = Task(priority: priority) {
            let isCompleted = LockIsolated(false)
            defer { isCompleted.setValue(true) }
            await operation(
              Send(isolation: self) { effectAction in
                if isCompleted.value {
//                  reportIssue(
//                    """
//                    An action was sent from a completed effect:
//
//                      Action:
//                        \(debugCaseOutput(effectAction))
//
//                      Effect returned from:
//                        \(debugCaseOutput(action))
//
//                    Avoid sending actions using the 'send' argument from 'Effect.run' after \
//                    the effect has completed. This can happen if you escape the 'send' \
//                    argument in an unstructured context.
//
//                    To fix this, make sure that your 'run' closure does not return until \
//                    you're done calling 'send'.
//                    """
//                  )
                }
                if let task = continuation.yield({
                  self.assumeIsolated { [effectAction = UncheckedSendable(effectAction)] in
                    $0.send(effectAction.wrappedValue, originatingFrom: nil)
                  }
                }) {
                  tasks.withValue { $0.append(task) }
                }
              }
            )
          }
          tasks.withValue { $0.append(task) }
        }
      }
    }

    guard !tasks.isEmpty else { return nil }
    return Task { @MainActor in
      await withTaskCancellationHandler {
        var index = tasks.startIndex
        while index < tasks.endIndex {
          defer { index += 1 }
          await tasks[index].value
        }
      } onCancel: {
        var index = tasks.startIndex
        while index < tasks.endIndex {
          defer { index += 1 }
          tasks[index].cancel()
        }
      }
    }
  }
  private actor DefaultIsolation {}
}

final actor ScopedCore<Base: Core, State, Action>: Core {
  let base: Base
  let stateKeyPath: _KeyPath<Base.State, State>
  let actionKeyPath: _CaseKeyPath<Base.Action, Action>
  init(
    base: Base,
    stateKeyPath: _KeyPath<Base.State, State>,
    actionKeyPath: _CaseKeyPath<Base.Action, Action>
  ) {
    self.base = base
    self.stateKeyPath = stateKeyPath
    self.actionKeyPath = actionKeyPath
  }
  nonisolated var unownedExecutor: UnownedSerialExecutor {
    base.unownedExecutor
  }
  @inlinable
  @inline(__always)
  var state: State {
    base.assumeIsolated { UncheckedSendable($0.state[keyPath: stateKeyPath]) }.wrappedValue
  }
  @inlinable
  @inline(__always)
  func send(_ action: Action) -> Task<Void, Never>? {
    base.assumeIsolated { [action = UncheckedSendable(action)] in $0.send(actionKeyPath(action.wrappedValue)) }
  }
  @inlinable
  @inline(__always)
  var canStoreCacheChildren: Bool {
    base.assumeIsolated { $0.canStoreCacheChildren }
  }
  @inlinable
  @inline(__always)
  var didSet: CurrentValueRelay<Void> {
    base.assumeIsolated { $0.didSet }
  }
  @inlinable
  @inline(__always)
  var isInvalid: Bool {
    base.assumeIsolated { $0.isInvalid }
  }
  @inlinable
  @inline(__always)
  var effectCancellables: [UUID: AnyCancellable] {
    base.assumeIsolated { UncheckedSendable($0.effectCancellables) }.wrappedValue
  }
}

final actor IfLetCore<Base: Core, State, Action>: Core {
  let base: Base
  var cachedState: State
  let stateKeyPath: _KeyPath<Base.State, State?>
  let actionKeyPath: _CaseKeyPath<Base.Action, Action>
  var parentCancellable: AnyCancellable?
  init(
    base: Base,
    cachedState: State,
    stateKeyPath: _KeyPath<Base.State, State?>,
    actionKeyPath: _CaseKeyPath<Base.Action, Action>
  ) {
    self.base = base
    self.cachedState = cachedState
    self.stateKeyPath = stateKeyPath
    self.actionKeyPath = actionKeyPath
  }
  nonisolated var unownedExecutor: UnownedSerialExecutor {
    base.unownedExecutor
  }
  @inlinable
  @inline(__always)
  var state: State {
    let state = base.assumeIsolated { UncheckedSendable($0.state[keyPath: stateKeyPath]) }.wrappedValue ?? cachedState
    cachedState = state
    return state
  }
  @inlinable
  @inline(__always)
  func send(_ action: Action) -> Task<Void, Never>? {
    #if DEBUG
      if BindingLocal.isActive && isInvalid {
        return nil
      }
    #endif
    return base.assumeIsolated { [action = UncheckedSendable(action)] in $0.send(actionKeyPath(action.wrappedValue)) }
  }
  @inlinable
  @inline(__always)
  var canStoreCacheChildren: Bool {
    base.assumeIsolated { $0.canStoreCacheChildren }
  }
  @inlinable
  @inline(__always)
  var didSet: CurrentValueRelay<Void> {
    base.assumeIsolated { $0.didSet }
  }
  @inlinable
  @inline(__always)
  var isInvalid: Bool {
    base.assumeIsolated { $0.state[keyPath: stateKeyPath] == nil || $0.isInvalid }
  }
  @inlinable
  @inline(__always)
  var effectCancellables: [UUID: AnyCancellable] {
    base.assumeIsolated { UncheckedSendable($0.effectCancellables) }.wrappedValue
  }
}

final actor ClosureScopedCore<Base: Core, State, Action>: Core {
  let base: Base
  let toState: (Base.State) -> State
  let fromAction: (Action) -> Base.Action
  init(
    base: Base,
    toState: @escaping (Base.State) -> State,
    fromAction: @escaping (Action) -> Base.Action
  ) {
    self.base = base
    self.toState = toState
    self.fromAction = fromAction
  }
  nonisolated var unownedExecutor: UnownedSerialExecutor {
    base.unownedExecutor
  }
  @inlinable
  @inline(__always)
  var state: State {
    toState(base.assumeIsolated { UncheckedSendable($0.state) }.wrappedValue)
  }
  @inlinable
  @inline(__always)
  func send(_ action: Action) -> Task<Void, Never>? {
    let action = UncheckedSendable(fromAction(action))
    return base.assumeIsolated { $0.send(action.wrappedValue) }
  }
  @inlinable
  @inline(__always)
  var canStoreCacheChildren: Bool {
    false
  }
  @inlinable
  @inline(__always)
  var didSet: CurrentValueRelay<Void> {
    base.assumeIsolated { $0.didSet }
  }
  @inlinable
  @inline(__always)
  var isInvalid: Bool {
    base.assumeIsolated { $0.isInvalid }
  }
  @inlinable
  @inline(__always)
  var effectCancellables: [UUID: AnyCancellable] {
    base.assumeIsolated { UncheckedSendable($0.effectCancellables) }.wrappedValue
  }
}
