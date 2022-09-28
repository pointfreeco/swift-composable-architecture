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
    static let liveValue = OpenURLEffect { _ in .systemAction }
    static let testValue = OpenURLEffect { _ in
      XCTFail(#"Unimplemented: @Dependency(\.openURL)"#)
      return .discarded
    }
  }
}

public struct OpenURLEffect: Sendable {
  public struct Result {
    fileprivate enum Value {
      case discarded
      case handled
      case systemAction(URL?)
    }

    public static var discarded: Self {
      Self(value: .discarded)
    }

    public static var handled: Self {
      Self(value: .handled)
    }

    public static var systemAction: Self {
      Self(value: .systemAction(nil))
    }

    public static func systemAction(_ url: URL) -> Self {
      Self(value: .systemAction(url))
    }

    fileprivate let value: Value
  }

  private let handler: @Sendable (URL) async -> Result

  init(handler: @escaping @Sendable (URL) async -> Result) {
    self.handler = handler
  }

  @discardableResult
  public func callAsFunction(_ url: URL) async -> Bool {
    let finalURL: URL
    switch await handler(url).value {
    case .discarded:
      return false
    case .handled:
      return true
    case let .systemAction(.some(url)):
      finalURL = url
    case .systemAction(.none):
      finalURL = url
    }
    let stream = AsyncStream<Bool> { continuation in
      Task { @MainActor in
        #if canImport(AppKit)
          NSWorkspace.shared.open(finalURL, configuration: .init()) { _, error in
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
      }
    }
    return await stream.first { _ in true } ?? false
  }
}
