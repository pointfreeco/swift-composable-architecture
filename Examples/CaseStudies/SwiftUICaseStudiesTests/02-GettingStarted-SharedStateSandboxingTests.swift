import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class SharedStateSandboxingTests: XCTestCase {
  @MainActor
  func testBasics() async {
    let store = TestStore(initialState: SharedStateSandboxing.State()) {
      SharedStateSandboxing()
    }

    await store.send(.incrementAppStorage) {
      $0.appStorageCount = 1
    }
    await store.send(.incrementFileStorage) {
      $0.fileStorageCount = 1
    }
    await store.send(.presentButtonTapped) {
      $0.sandboxed = withDependencies {
        let suiteName = "sandbox"
        let defaultAppStorage = UserDefaults(suiteName: suiteName)!
        defaultAppStorage.removePersistentDomain(forName: suiteName)
        $0.defaultAppStorage = defaultAppStorage
        $0.defaultFileStorage = EphemeralFileStorage()
      } operation: {
        SharedStateSandboxing.State()
      }
    }
    await store.send(.sandboxed(.presented(.incrementAppStorage))) {
      $0.sandboxed?.appStorageCount = 1
    }
    await store.send(.sandboxed(.presented(.incrementFileStorage))) {
      $0.sandboxed?.fileStorageCount = 1
    }
  }
}
