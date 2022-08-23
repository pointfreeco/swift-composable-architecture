import Combine
import ComposableArchitecture
import Foundation
import XCTestDynamicOverlay

struct DownloadClient {
  var download: @Sendable (URL) -> AsyncThrowingStream<Event, Error>

  enum Event: Equatable {
    case response(Data)
    case updateProgress(Double)
  }
}

extension DependencyValues {
  var downloadClient: DownloadClient {
    get { self[DownloadClientKey.self] }
    set { self[DownloadClientKey.self] = newValue }
  }

  private enum DownloadClientKey: DependencyKey {
    static let liveValue = DownloadClient.live
    static let testValue = DownloadClient.unimplemented
  }
}

extension DownloadClient {
  static let live = DownloadClient(
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

  static let unimplemented = DownloadClient(
    download: XCTUnimplemented("\(Self.self).download")
  )
}
