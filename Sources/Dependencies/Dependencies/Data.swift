import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
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

public struct DataReader: Sendable {
  private var contentsOfURL: @Sendable (URL, Data.ReadingOptions) throws -> Data

  public init(contentsOfURL: @escaping @Sendable (URL, Data.ReadingOptions) throws -> Data) {
    self.contentsOfURL = contentsOfURL
  }

  public func callAsFunction(contentsOfURL url: URL, options: Data.ReadingOptions = []) throws -> Data {
    try self.contentsOfURL(url, options)
  }
}
