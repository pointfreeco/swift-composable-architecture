#if canImport(Combine)
  import Combine
#else
  import OpenCombine
#endif

extension Effect {
  /// Creates an effect from a Combine publisher.
  ///
  /// - Parameter createPublisher: The closure to execute when the effect is performed.
  /// - Returns: An effect wrapping a Combine publisher.
  public static func publisher(_ createPublisher: () -> some Publisher<Action, Never>) -> Self {
    Self(operation: .publisher(createPublisher().eraseToAnyPublisher()))
  }
}

public struct _EffectPublisher<Action>: Publisher {
  public typealias Output = Action
  public typealias Failure = Never

  let effect: Effect<Action>

  public init(_ effect: Effect<Action>) {
    self.effect = effect
  }

  #if canImport(Combine)
    public func receive(subscriber: some Combine.Subscriber<Action, Failure>) {
      publisher.subscribe(subscriber)
    }
  #else
    public func receive<Downstream: OpenCombine.Subscriber>(subscriber: Downstream)
    where Downstream.Failure == Failure, Downstream.Input == Output {
      publisher.subscribe(subscriber)
    }
  #endif

  private var publisher: AnyPublisher<Action, Failure> {
    switch effect.operation {
    case .none:
      return Empty().eraseToAnyPublisher()
    case .publisher(let publisher):
      return publisher
    case .run(let name, let priority, let operation):
      return .create { subscriber in
        let task = Task(name: name, priority: priority) { @MainActor in
          defer { subscriber.send(completion: .finished) }
          await operation(Send { subscriber.send($0) })
        }
        return AnyCancellable { @Sendable in
          task.cancel()
        }
      }
    }
  }
}
