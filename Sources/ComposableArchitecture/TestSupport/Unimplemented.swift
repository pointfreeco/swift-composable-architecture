import XCTestDynamicOverlay

/// <#Description#>
/// - Parameters:
///   - type: <#type description#>
///   - endpoint: <#endpoint description#>
/// - Returns: <#description#>
public func unimplemented<A, B>(_ type: Any.Type, endpoint: String) -> (A) async throws -> B {
  { a in
    XCTFail("\(type).\(endpoint) unimplemented.")
    throw Unimplemented(endpoint: endpoint)
  }
}

public func unimplemented<A, B>(_ type: Any.Type, endpoint: String, default: B) -> (A) async -> B {
  { a in
    XCTFail("\(type).\(endpoint) unimplemented.")
    return `default`
  }
}

private struct Unimplemented: Error {
  let endpoint: String
}
