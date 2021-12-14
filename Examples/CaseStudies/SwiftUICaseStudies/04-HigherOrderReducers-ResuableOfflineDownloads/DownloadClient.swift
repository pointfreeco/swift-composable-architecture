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
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        let length = response.expectedContentLength
        var data = Data(capacity: Int(length))
        for try await byte in bytes {
          data.append(byte)
          continuation.yield(.updateProgress(Double(data.count) / Double(length)))
        }
        continuation.yield(.response(data))
        continuation.finish()
      }
    }
  )
}
