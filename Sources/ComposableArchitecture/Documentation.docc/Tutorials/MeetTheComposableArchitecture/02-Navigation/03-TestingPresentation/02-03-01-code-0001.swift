import ComposableArchitecture
import XCTest

@testable import ContactsApp

@MainActor
final class ContactsFeatureTests: XCTestCase {
  func testAddFlow() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    }
  }
}
