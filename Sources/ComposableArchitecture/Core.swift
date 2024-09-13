import Combine
import Foundation

@MainActor
protocol Core<State, Action>: AnyObject, Sendable {
  associatedtype State
  associatedtype Action
  var state: State { get }
  func send(_ action: Action) -> Task<Void, Never>?

  var canStoreCacheChildren: Bool { get }
  var didSet: CurrentValueRelay<Void> { get }
  var isInvalid: Bool { get }

  var effectCancellables: [UUID: AnyCancellable] { get }
}

final class InvalidCore<State, Action>: Core {
  var state: State {
    get { fatalError() }
    set { fatalError() }
  }
  func send(_ action: Action) -> Task<Void, Never>? { nil }

  var canStoreCacheChildren: Bool { false }
  let didSet = CurrentValueRelay<Void>(())
  var isInvalid: Bool { true }
  var effectCancellables: [UUID: AnyCancellable] { [:] }
}

final class RootCore<Root: Reducer>: Core {
  var state: Root.State {
    didSet {
      didSet.send(())
    }
  }
  let reducer: Root

  var canStoreCacheChildren: Bool { true }
  let didSet = CurrentValueRelay(())
  var isInvalid: Bool { false }

  private var bufferedActions: [Root.Action] = []
  var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  init(
    initialState: Root.State,
    reducer: Root
  ) {
    self.state = initialState
    self.reducer = reducer
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
          publisher
            .receive(on: UIScheduler.shared)
            .handleEvents(receiveCancel: { [weak self] in self?.effectCancellables[uuid] = nil })
            .sink(
              receiveCompletion: { [weak self] _ in
                boxedTask.wrappedValue?.cancel()
                didComplete = true
                self?.effectCancellables[uuid] = nil
              },
              receiveValue: { [weak self] effectAction in
                guard let self else { return }
                if let task = continuation.yield({
                  self.send(effectAction, originatingFrom: action)
                }) {
                  tasks.withValue { $0.append(task) }
                }
              }
            )
        }

        if !didComplete {
          let task = Task<Void, Never> { @MainActor in
            for await _ in AsyncStream<Void>.never {}
            effectCancellable.cancel()
          }
          boxedTask.wrappedValue = task
          tasks.withValue { $0.append(task) }
          self.effectCancellables[uuid] = effectCancellable
        }
      case let .run(priority, operation):
        withEscapedDependencies { continuation in
          let task = Task(priority: priority) { @MainActor in
            let isCompleted = LockIsolated(false)
            defer { isCompleted.setValue(true) }
            await operation(
              Send { effectAction in
                if isCompleted.value {
                  reportIssue(
                    """
                    An action was sent from a completed effect:

                      Action:
                        \(debugCaseOutput(effectAction))

                      Effect returned from:
                        \(debugCaseOutput(action))

                    Avoid sending actions using the 'send' argument from 'Effect.run' after \
                    the effect has completed. This can happen if you escape the 'send' \
                    argument in an unstructured context.

                    To fix this, make sure that your 'run' closure does not return until \
                    you're done calling 'send'.
                    """
                  )
                }
                if let task = continuation.yield({
                  self.send(effectAction, originatingFrom: action)
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

class ScopedCore<Base: Core, State, Action>: Core {
  var base: Base
  let stateKeyPath: KeyPath<Base.State, State>
  let actionKeyPath: CaseKeyPath<Base.Action, Action>
  init(
    base: Base,
    stateKeyPath: KeyPath<Base.State, State>,
    actionKeyPath: CaseKeyPath<Base.Action, Action>
  ) {
    self.base = base
    self.stateKeyPath = stateKeyPath
    self.actionKeyPath = actionKeyPath
  }
  var state: State {
    base.state[keyPath: stateKeyPath]
  }
  func send(_ action: Action) -> Task<Void, Never>? {
    base.send(actionKeyPath(action))
  }
  var canStoreCacheChildren: Bool {
    base.canStoreCacheChildren
  }
  var didSet: CurrentValueRelay<Void> {
    base.didSet
  }
  var isInvalid: Bool {
    base.isInvalid
  }
  var effectCancellables: [UUID: AnyCancellable] {
    base.effectCancellables
  }
}

class IfLetCore<Base: Core, State, Action>: Core {
  var base: Base
  var cachedState: State
  let stateKeyPath: KeyPath<Base.State, State?>
  let actionKeyPath: CaseKeyPath<Base.Action, Action>
  init(
    base: Base,
    cachedState: State,
    stateKeyPath: KeyPath<Base.State, State?>,
    actionKeyPath: CaseKeyPath<Base.Action, Action>
  ) {
    self.base = base
    self.cachedState = cachedState
    self.stateKeyPath = stateKeyPath
    self.actionKeyPath = actionKeyPath
  }
  var state: State {
    base.state[keyPath: stateKeyPath] ?? cachedState
  }
  func send(_ action: Action) -> Task<Void, Never>? {
    #if DEBUG
      if BindingLocal.isActive && base.state[keyPath: stateKeyPath] == nil {
        return nil
      }
    #endif
    return base.send(actionKeyPath(action))
  }
  var canStoreCacheChildren: Bool {
    base.canStoreCacheChildren
  }
  var didSet: CurrentValueRelay<Void> {
    base.didSet
  }
  var isInvalid: Bool {
    base.state[keyPath: stateKeyPath] == nil || base.isInvalid
  }
  var effectCancellables: [UUID: AnyCancellable] {
    base.effectCancellables
  }
}

class ClosureScopedCore<Base: Core, State, Action>: Core {
  var base: Base
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
  var state: State {
    toState(base.state)
  }
  func send(_ action: Action) -> Task<Void, Never>? {
    base.send(fromAction(action))
  }
  var canStoreCacheChildren: Bool {
    false
  }
  var didSet: CurrentValueRelay<Void> {
    base.didSet
  }
  var isInvalid: Bool {
    base.isInvalid
  }
  var effectCancellables: [UUID: AnyCancellable] {
    base.effectCancellables
  }
}
