#if canImport(Combine)
  import Combine

  extension _Effect {
    public static func publisher(_ publisher: some Publisher<Action, Never>) -> Self {
      nonisolated(unsafe)
      let publisher = publisher
      return .sync { continuation in
        nonisolated(unsafe)
        let cancellable =
        publisher
          .handleEvents(receiveCancel: { continuation.cancel() })
          .sink { _ in
            continuation.finish()
          } receiveValue: {
            continuation($0)
          }
        continuation.onTermination = { _ in
          cancellable.cancel()
        }
      }
    }

    public static func publisher(_ publisher: () -> some Publisher<Action, Never>) -> Self {
      self.publisher(publisher())
    }

    public var publisher: AnyPublisher<Action, Never> {
      .create { subscriber in
        let task = self.run { action in
          subscriber.send(action)
        } onTermination: { _ in
          subscriber.send(completion: .finished)
        }
        return AnyCancellable {
          task.cancel()
        }
      }
    }
  }
#endif
