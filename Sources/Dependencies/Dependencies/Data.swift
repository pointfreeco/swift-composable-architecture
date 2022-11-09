import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  /// A dependency that reads data from a specified URL.
  ///
  /// By default, a "live" reader is supplied, which returns the real disk/remote data reading
  /// mechanism called by invoking `Data.init(contentsOf:options:)` under the hood. When used
  /// from a `TestStore`, an "unimplemented" reader that returns empty `Data` and additionally
  /// reports test failures is supplied, unless explicitly overridden.
  ///
  /// To override the current data reading logic in tests, you can override the reader using
  /// ``withValue(_:_:operation:)-705n``:
  ///
  /// ```swift
  /// DependencyValues.withValue(\.data, .init(contentsOfURL: { _, _ in Data("deadbeef".utf8) })) {
  ///   // Assertions...
  /// }
  /// ```
  ///
  /// Or, if you are using the Composable Architecture, you can override dependencies directly
  /// on the `TestStore`:
  ///
  /// ```swift
  /// let store = TestStore(
  ///   initialState: MyFeature.State()
  ///   reducer: MyFeature()
  /// )
  ///
  /// store.dependencies.data = .init(contentsOfURL: { _, _ in Data("deadbeef".utf8) })
  /// ```
  public var data: DataReader {
    get { self[DataReaderKey.self] }
    set { self[DataReaderKey.self] = newValue }
  }

  private enum DataReaderKey: DependencyKey {
    static let liveValue = DataReader(
      contentsOfURL: { @Sendable url, options in
        try Data(contentsOf: url, options: options)
      }
    )
    static let testValue = DataReader { _, _ in
      XCTFail(#"Unimplemented: @Dependency(\.data)"#)
      return Data()
    }
  }
}

/// A dependency that reads data from a specified URL.
///
/// See ``DependencyValues/data`` for more information.
public struct DataReader: Sendable {
  private var contentsOfURL: @Sendable (URL, Data.ReadingOptions) throws -> Data

  /// Initializes a data reader that reads data via a closure.
  ///
  /// - Parameter contentsOfURL: A closure that returns data from a URL when called.
  public init(contentsOfURL: @escaping @Sendable (URL, Data.ReadingOptions) throws -> Data) {
    self.contentsOfURL = contentsOfURL
  }

  public func callAsFunction(contentsOfURL url: URL, options: Data.ReadingOptions = []) throws -> Data {
    try self.contentsOfURL(url, options)
  }
}
