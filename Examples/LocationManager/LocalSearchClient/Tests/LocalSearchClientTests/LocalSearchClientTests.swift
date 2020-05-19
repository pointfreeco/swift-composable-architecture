import XCTest
@testable import LocalSearchClient

final class LocalSearchClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(LocalSearchClient().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
