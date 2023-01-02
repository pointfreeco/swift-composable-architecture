import XCTestDynamicOverlay

#if canImport(SwiftUI)
  import SwiftUI

  extension DependencyValues {
    /// A dependency that opens a URL.
    @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
    public var openURL: OpenURLEffect {
      get { self[OpenURLKey.self] }
      set { self[OpenURLKey.self] = newValue }
    }
  }

  @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
  private enum OpenURLKey: DependencyKey {
    static let liveValue = OpenURLEffect { url in
      let stream = AsyncStream<Bool> { continuation in
        let task = Task { @MainActor in
          #if os(watchOS)
            EnvironmentValues().openURL(url)
            continuation.yield(true)
            continuation.finish()
          #else
            EnvironmentValues().openURL(url) { canOpen in
              continuation.yield(canOpen)
              continuation.finish()
            }
          #endif
        }
        continuation.onTermination = { @Sendable _ in
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

  public struct OpenURLEffect: Sendable {
    private let handler: @Sendable (URL) async -> Bool

    public init(handler: @escaping @Sendable (URL) async -> Bool) {
      self.handler = handler
    }

    @available(watchOS, unavailable)
    @discardableResult
    public func callAsFunction(_ url: URL) async -> Bool {
      await self.handler(url)
    }

    @_disfavoredOverload
    public func callAsFunction(_ url: URL) async {
      _ = await self.handler(url)
    }
  }
#endif
