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
      AsyncThrowingStream { continuation in
        Task {
          defer { continuation.finish() }
          let (bytes, response) = try await URLSession.shared.bytes(from: url)
          let length = response.expectedContentLength
          var data = Data()
          data.reserveCapacity(Int(length))
          for try await byte in bytes {
            data.append(byte)
            let progress = Double(data.count) / Double(length)
            continuation.yield(.updateProgress(progress))
          }
          continuation.yield(.response(data))
        }
      }
    }
  )
}
