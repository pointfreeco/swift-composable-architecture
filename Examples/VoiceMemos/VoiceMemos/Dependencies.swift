import Dependencies
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
  var openSettings: @Sendable () async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }

  private enum OpenSettingsKey: DependencyKey {
    typealias Value = @Sendable () async -> Void

    static let liveValue: @Sendable () async -> Void = {
      await MainActor.run {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
      }
    }
    static let testValue: @Sendable () async -> Void = unimplemented(
      #"@Dependency(\.openSettings)"#
    )
  }

  var temporaryDirectory: @Sendable () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }

  private enum TemporaryDirectoryKey: DependencyKey {
    static let liveValue: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
    static let testValue: @Sendable () -> URL = unimplemented(
      #"@Dependency(\.temporaryDirectory)"#
    )
  }
}
