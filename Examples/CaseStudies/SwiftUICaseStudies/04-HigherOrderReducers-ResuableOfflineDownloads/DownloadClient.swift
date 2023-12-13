import ComposableArchitecture
import Foundation

@DependencyClient
struct DownloadClient {
  var download: @Sendable (_ url: URL) -> AsyncThrowingStream<Event, Error> = { _ in .finished() }

  @CasePathable
  enum Event: Equatable {
    case response(Data)
    case updateProgress(Double)
  }
}

extension DependencyValues {
  var downloadClient: DownloadClient {
    get { self[DownloadClient.self] }
    set { self[DownloadClient.self] = newValue }
  }
}

extension DownloadClient: DependencyKey {
  static let liveValue = Self(
    download: { url in
      .init { continuation in
        Task {
          do {
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            var data = Data()
            var progress = 0
            for try await byte in bytes {
              data.append(byte)
              let newProgress = Int(
                Double(data.count) / Double(response.expectedContentLength) * 100)
              if newProgress != progress {
                progress = newProgress
                continuation.yield(.updateProgress(Double(progress) / 100))
              }
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

  static let testValue = Self()
}
