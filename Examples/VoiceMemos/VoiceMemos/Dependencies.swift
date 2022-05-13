import ComposableArchitecture
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
  var openSettings: Effect<Never, Never> {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }

  private enum OpenSettingsKey: LiveDependencyKey {
    static let liveValue = Effect<Never, Never>.fireAndForget {
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
    static let testValue = Effect<Never, Never>.failing(#"@Dependency(\.openSettings)"#)
  }

  var temporaryDirectory: () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }

  private enum TemporaryDirectoryKey: LiveDependencyKey {
    static let liveValue: () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
    static let testValue: () -> URL = {
      XCTFail("VoiceMemosEnvironment.temporaryDirectory is unimplemented")
      return URL(fileURLWithPath: NSTemporaryDirectory())
    }
  }
}
