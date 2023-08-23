#if canImport(Combine)
  import Combine

  extension Effect {
    /// Creates an effect from a Combine publisher.
    ///
    /// - Parameter createPublisher: The closure to execute when the effect is performed.
    /// - Returns: An effect wrapping a Combine publisher.
    public static func publisher<P: Publisher>(_ createPublisher: @escaping () -> P) -> Self
    where P.Output == Action, P.Failure == Never {
      return .init(
        operation: .init(
          sync: { continuation in
            let cancellable = createPublisher().sink(
              receiveCompletion: { _ in
                continuation.finish()
              },
              receiveValue: { continuation($0) }
            )
            continuation.onTermination { _ in
              _ = cancellable
              //cancellable.cancel()
            }
          },
          async: nil
        )
      )
    }
  }

  public struct _EffectPublisher<Action>: Publisher {
    public typealias Output = Action
    public typealias Failure = Never

    let effect: Effect<Action>

    public init(_ effect: Effect<Action>) {
      self.effect = effect
    }

    public func receive<S: Combine.Subscriber>(
      subscriber: S
    ) where S.Input == Action, S.Failure == Failure {
      self.publisher.subscribe(subscriber)
    }

    private var publisher: AnyPublisher<Action, Failure> {
      return Empty(completeImmediately: true).eraseToAnyPublisher()
      fatalError("TODO")

//      switch self.effect.operation {
//      case .none:
//        return Empty().eraseToAnyPublisher()
//      case let .publisher(publisher):
//        return publisher
//      case let .run(priority, operation):
//        return .create { subscriber in
//          let task = Task(priority: priority) { @MainActor in
//            defer { subscriber.send(completion: .finished) }
//            await operation(Send { subscriber.send($0) })
//          }
//          return AnyCancellable {
//            task.cancel()
//          }
//        }
//      }
    }
  }
#endif
