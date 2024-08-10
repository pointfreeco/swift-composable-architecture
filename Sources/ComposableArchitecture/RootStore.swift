import Combine
import Foundation

@_spi(Internals)
@MainActor
public final class RootStore {
  private var bufferedActions: [Any] = []
  let didSet = CurrentValueRelay(())
  @_spi(Internals) public var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  private let reducer: any Reducer
  private(set) var state: Any {
    didSet {
      didSet.send(())
    }
  }

  init<State, Action>(
    initialState: State,
    reducer: some Reducer<State, Action>
  ) {
    self.state = initialState
    self.reducer = reducer
  }

  func send(_ action: Any, originatingFrom originatingAction: Any? = nil) -> Task<Void, Never>? {
    func open<State, Action>(reducer: some Reducer<State, Action>) -> Task<Void, Never>? {
      self.bufferedActions.append(action)
      guard !self.isSending else { return nil }

      self.isSending = true
      var currentState = self.state as! State
      let tasks = Box<[Task<Void, Never>]>(wrappedValue: [])
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
            tasks.wrappedValue.append(task)
          }
        }
      }

      var index = self.bufferedActions.startIndex
      while index < self.bufferedActions.endIndex {
        defer { index += 1 }
        let action = self.bufferedActions[index] as! Action
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
                    tasks.wrappedValue.append(task)
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
            tasks.wrappedValue.append(task)
            self.effectCancellables[uuid] = effectCancellable
          }
        case let .run(priority, operation):
          withEscapedDependencies { continuation in
            tasks.wrappedValue.append(
              Task(priority: priority) { @MainActor in
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
                      tasks.wrappedValue.append(task)
                    }
                  }
                )
              }
            )
          }
        }
      }

      guard !tasks.wrappedValue.isEmpty else { return nil }
      return Task { @MainActor in
        await withTaskCancellationHandler {
          var index = tasks.wrappedValue.startIndex
          while index < tasks.wrappedValue.endIndex {
            defer { index += 1 }
            await tasks.wrappedValue[index].value
          }
        } onCancel: {
          var index = tasks.wrappedValue.startIndex
          while index < tasks.wrappedValue.endIndex {
            defer { index += 1 }
            tasks.wrappedValue[index].cancel()
          }
        }
      }
    }
    #if canImport(Perception)
      return _withoutPerceptionChecking {
        open(reducer: self.reducer)
      }
    #else
      return open(reducer: self.reducer)
    #endif
  }
}
