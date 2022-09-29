import Dependencies
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
  var openSettings: @Sendable () async -> Void {
    get {
      return {
        await self.openURL(URL(string: UIApplication.openSettingsURLString)!)
      }
    }
    set {
      self.openURL = .init { _ in
        await newValue()
        return true
      }
    }
  }

  var temporaryDirectory: @Sendable () -> URL {
    get { self[TemporaryDirectoryKey.self] }
    set { self[TemporaryDirectoryKey.self] = newValue }
  }

  private enum TemporaryDirectoryKey: DependencyKey {
    static let liveValue: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
  }
}
