@preconcurrency import Combine

extension AsyncSequence {
  var publisher: AnyPublisher<Element, Error> {
    let subject = PassthroughSubject<Element, Error>()
    let task = Task {
      do {
        try await withTaskCancellationHandler(
          handler: {
            subject.send(completion: .finished)
          },
          operation: {
            for try await element in self {
              subject.send(element)
            }
            subject.send(completion: .finished)
          }
        )
      } catch {
        subject.send(completion: .failure(error))
      }
    }
    return subject
      .handleEvents(
        receiveCompletion: { _ in
          task.cancel()
        },
        receiveCancel: {
          task.cancel()
        }
      )
      .eraseToAnyPublisher()
  }
}
