import ComposableArchitecture
import XCTest

@testable import ContactsApp

final class ContactsFeatureTests: XCTestCase {
  func testDeleteContact() async {
    let store = await TestStore(
      initialState: ContactsFeature.State(
        contacts: [
          Contact(id: UUID(0), name: "Blob"),
          Contact(id: UUID(1), name: "Blob Jr."),
        ]
      )
    ) {
      ContactsFeature()
    }
  }
}
