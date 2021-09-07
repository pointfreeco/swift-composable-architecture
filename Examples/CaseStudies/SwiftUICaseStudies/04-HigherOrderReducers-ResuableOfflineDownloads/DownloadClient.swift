import Combine
import ComposableArchitecture
import Foundation

struct DownloadClient {
  var download: (URL) -> Effect<Action, Error>

  struct Error: Swift.Error, Equatable {}

  enum Action: Equatable {
    case response(Data)
    case updateProgress(Double)
  }
}

extension DownloadClient {
  static let live = DownloadClient(
    download: { url in
      .run { subscriber in
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
          switch (data, error) {
          case let (.some(data), _):
            subscriber.send(.response(data))
            subscriber.send(completion: .finished)
          case let (_, .some(error)):
            subscriber.send(completion: .failure(Error()))
          case (.none, .none):
            fatalError("Data and Error should not both be nil")
          }
        }

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
          subscriber.send(.updateProgress(progress.fractionCompleted))
        }

        task.resume()

        return AnyCancellable {
          observation.invalidate()
          task.cancel()
        }
      }
    }
  )
}
