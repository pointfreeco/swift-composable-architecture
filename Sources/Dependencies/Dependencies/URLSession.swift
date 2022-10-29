import Foundation
import XCTestDynamicOverlay

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension DependencyValues {
  /// The URL session that features should use to make URL requests.
  ///
  /// By default, the session returned from `URLSession.shared` is supplied. When used from a
  /// `TestStore`, access will call to `XCTFail` when invoked, unless explicitly overridden:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: MyFeature.State()
  ///   reducer: MyFeature()
  /// )
  ///
  /// let mockConfiguration = URLSessionConfiguration.ephemeral
  /// mockConfiguration.protocolClasses = [MyMockURLProtocol.self]
  /// store.dependencies.urlSession = URLSession(configuration: mockConfiguration)
  /// ```
  ///
  /// ### API client dependencies
  ///
  /// While it is possible to use this dependency value from more complex dependencies, like API
  /// clients, we generally advise against _designing_ a dependency around a URL session. Mocking a
  /// URL session's responses is a complex process that requires a lot of work that can be avoided.
  ///
  /// For example, instead of defining your dependency in a way that holds directly onto a URL
  /// session in order to invoke it from a concrete implementation:
  ///
  /// ```swift
  /// struct APIClient {
  ///   let urlSession: URLSession
  ///
  ///   func fetchProfile() async throws -> Profile {
  ///     // Use URL session to make request
  ///   }
  ///
  ///   func fetchTimeline() async throws -> Timeline { /* ... */ }
  ///   // ...
  /// }
  /// ```
  ///
  /// Define your dependency as a lightweight _interface_ that holds onto endpoints that can be
  /// individually overridden in a lightweight fashion:
  ///
  /// ```swift
  /// struct APIClient {
  ///   var fetchProfile: () async throws -> Profile
  ///   var fetchTimeline: () async throws -> Timeline
  ///   // ...
  /// }
  /// ```
  ///
  /// Then, you can extend this type with a live implementation that uses a URL session under the
  /// hood:
  ///
  /// ```swift
  /// extension APIClient {
  ///   static func live(urlSession: URLSession) -> Self {
  ///     Self(
  ///       fetchProfile: {
  ///         // Use URL session to make request
  ///       }
  ///       fetchTimeline: { /* ... */ },
  ///       // ...
  ///     )
  ///   }
  /// }
  /// ```
  public var urlSession: URLSession {
    get { self[URLSessionKey.self] }
    set { self[URLSessionKey.self] = newValue }
  }

  private enum URLSessionKey: DependencyKey {
    static let liveValue = URLSession.shared
    static var testValue: URLSession {
      if !DependencyValues.isSetting {
        XCTFail(#"Unimplemented: @Dependency(\.urlSession)"#)
      }
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [UnimplementedURLProtocol.self]
      return URLSession(configuration: configuration)
    }
  }
}

private final class UnimplementedURLProtocol: URLProtocol {
  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    struct UnimplementedURLSession: Error {}
    self.client?.urlProtocol(self, didFailWithError: UnimplementedURLSession())
  }

  override func stopLoading() {
  }
}
