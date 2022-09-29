#if !os(watchOS)
import XCTestDynamicOverlay

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif

extension DependencyValues {
  var openURL: OpenURLEffect {
    get { self[OpenURLKey.self] }
    set { self[OpenURLKey.self] = newValue }
  }

  private enum OpenURLKey: DependencyKey {
    static let liveValue = OpenURLEffect { url in
      let stream = AsyncStream<Bool> { continuation in
        let task = Task { @MainActor in
          #if canImport(AppKit)
            NSWorkspace.shared.open(url, configuration: .init()) { _, error in
              continuation.yield(error == nil)
              continuation.finish()
            }
          #endif
          #if canImport(UIKit)
            UIApplication.shared.open(url) { canOpen in
              continuation.yield(canOpen)
              continuation.finish()
            }
          #endif
          // TODO: Make sure `tvOS` and `watchOS` behave like `EnvironmentValues.openURL`?
        }
        continuation.onTermination = { _ in
          task.cancel()
        }
      }
      return await stream.first(where: { _ in true }) ?? false
    }
    static let testValue = OpenURLEffect { _ in
      XCTFail(#"Unimplemented: @Dependency(\.openURL)"#)
      return false
    }
  }
}

public struct OpenURLEffect: Sendable {
  private let handler: @Sendable (URL) async -> Bool

  init(handler: @escaping @Sendable (URL) async -> Bool) {
    self.handler = handler
  }

  @discardableResult
  public func callAsFunction(_ url: URL) async -> Bool {
    await self.handler(url)
  }
}
#endif
