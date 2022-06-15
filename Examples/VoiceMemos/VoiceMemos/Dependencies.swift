import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
  var openSettings: @MainActor @Sendable () async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }

  private enum OpenSettingsKey: LiveDependencyKey {
    typealias Value = @MainActor @Sendable () async -> Void

    static let liveValue: @MainActor @Sendable () async -> Void = {
      await UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
    static let testValue: @MainActor @Sendable () async -> Void = {
      XCTFail(#"@Dependency(\.openSettings)"#)
    }
  }

  var temporaryDirectory: @Sendable () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }

  private enum TemporaryDirectoryKey: LiveDependencyKey {
    static let liveValue: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
    static let testValue: @Sendable () -> URL = {
      XCTFail("VoiceMemosEnvironment.temporaryDirectory is unimplemented")
      return URL(fileURLWithPath: NSTemporaryDirectory())
    }
  }
}
