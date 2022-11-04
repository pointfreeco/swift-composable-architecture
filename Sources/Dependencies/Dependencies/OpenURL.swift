import XCTestDynamicOverlay

#if canImport(AppKit)
  import AppKit
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

#if canImport(AppKit) || canImport(UIKit) || canImport(SwiftUI)
  extension DependencyValues {
    /// A dependency that opens a URL.
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 7, *)
    public var openURL: OpenURLEffect {
      get { self[OpenURLKey.self] }
      set { self[OpenURLKey.self] = newValue }
    }
  }

  private enum OpenURLKey: DependencyKey {
    static let liveValue = OpenURLEffect { url in
      let stream = AsyncStream<Bool> { continuation in
        let task = Task { @MainActor in
          #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            NSWorkspace.shared.open(url, configuration: .init()) { app, error in
              continuation.yield(app != nil && error == nil)
              continuation.finish()
            }
          #elseif canImport(UIKit) && !os(watchOS)
            UIApplication.shared.open(url) { canOpen in
              continuation.yield(canOpen)
              continuation.finish()
            }
          #elseif canImport(SwiftUI)
            if #available(watchOS 7, *) {
              EnvironmentValues().openURL(url)
              continuation.yield(true)
              continuation.finish()
            } else {
              continuation.yield(false)
              continuation.finish()
            }
          #else
            continuation.yield(false)
            continuation.finish()
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
