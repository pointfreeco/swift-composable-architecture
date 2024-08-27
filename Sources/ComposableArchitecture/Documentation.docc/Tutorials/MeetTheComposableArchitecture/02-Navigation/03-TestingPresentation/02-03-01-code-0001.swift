import ComposableArchitecture
import XCTest

@testable import ContactsApp

final class ContactsFeatureTests: XCTestCase {
  func testAddFlow() async {
    let store = await TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    }
  }
}
