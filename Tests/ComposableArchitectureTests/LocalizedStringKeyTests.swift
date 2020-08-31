import SwiftUI
import XCTest

@testable import ComposableArchitecture

class LocalizedStringKeyTests: XCTestCase {
  func testFormatting() {
    XCTAssertEqual(
      LocalizedStringKey("Hello, #\(42)!").formatted(),
      "Hello, #42!"
    )

    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    XCTAssertEqual(
      LocalizedStringKey("You are \(1_000 as NSNumber, formatter: formatter) in line.").formatted(),
      "You are 1,000th in line."
    )
  }
}
