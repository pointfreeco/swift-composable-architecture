import Combine
import ComposableArchitecture
import Foundation

struct DownloadClient {
  var download: (URL) -> AsyncThrowingStream<Action, Error>

  enum Action: Equatable {
    case response(Data)
    case updateProgress(Double)
  }
}

extension DownloadClient {
  static let live = DownloadClient(
    download: { url in
      .init { continuation in
        Task {
          do {
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            var data = Data(capacity: Int(response.expectedContentLength))
            for try await byte in bytes {
              data.append(byte)
              continuation.yield(.updateProgress(Double(data.count) / Double(response.expectedContentLength)))
            }
            continuation.yield(.response(data))
            continuation.finish()
          } catch {
            continuation.finish(throwing: error)
          }
        }
      }
    }
  )
}
