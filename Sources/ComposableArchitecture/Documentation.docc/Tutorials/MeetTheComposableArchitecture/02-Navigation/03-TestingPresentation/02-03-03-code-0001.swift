import ComposableArchitecture
import XCTest

@testable import ContactsApp

@MainActor
final class ContactsFeatureTests: XCTestCase {
  func testDeleteContact() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    }
  }
}
