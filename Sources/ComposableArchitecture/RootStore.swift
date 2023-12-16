import Combine
import Foundation

final class RootStore {
  let didSet = PassthroughSubject<Void, Never>()
  private(set) var state: Any {
    didSet {
      didSet.send()
    }
  }
  private let reducer: any Reducer

  private var bufferedActions: [Any] = []
  private var isSending = false
  @_spi(Internals) public var effectCancellables: [UUID: AnyCancellable] = [:]

  init<State, Action>(
    initialState: State,
    reducer: some Reducer<State, Action>
  ) {
    self.state = initialState
    self.reducer = reducer
  }

  func send(_ action: Any) -> Task<Void, Never>? {
    func open<State, Action>(reducer: some Reducer<State, Action>) -> Task<Void, Never>? {
      //self.threadCheck(status: .send(action, originatingAction: originatingAction))

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
            self.bufferedActions.removeLast()
              //, originatingFrom: originatingAction
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
              .handleEvents(
                receiveCancel: { [weak self] in
                  //self?.threadCheck(status: .effectCompletion(action))
                  self?.effectCancellables[uuid] = nil
                }
              )
              .sink(
                receiveCompletion: { [weak self] _ in
                  //self?.threadCheck(status: .effectCompletion(action))
                  boxedTask.wrappedValue?.cancel()
                  didComplete = true
                  self?.effectCancellables[uuid] = nil
                },
                receiveValue: { [weak self] effectAction in
                  guard let self = self else { return }
                  if let task = continuation.yield({
                    self.send(
                      effectAction
                      //, originatingFrom: action
                    )
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
                #if DEBUG
                  let isCompleted = LockIsolated(false)
                  defer { isCompleted.setValue(true) }
                #endif
                await operation(
                  Send { effectAction in
                    #if DEBUG
                      if isCompleted.value {
                        runtimeWarn(
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
                    #endif
                    if let task = continuation.yield({
                      self.send(
                        effectAction
                        //, originatingFrom: action
                      )
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
    return open(reducer: self.reducer)
  }
}
