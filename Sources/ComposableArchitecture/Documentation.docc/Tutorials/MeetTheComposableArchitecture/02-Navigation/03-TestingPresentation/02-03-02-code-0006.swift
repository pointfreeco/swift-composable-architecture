import ComposableArchitecture
import XCTest

@testable import ContactsApp

final class ContactsFeatureTests: XCTestCase {
  func testAddFlow_NonExhaustive() async {
    let store = await TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    } withDependencies: {
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off
    
    await store.send(.addButtonTapped)
    await store.send(\.destination.addContact.setName, "Blob Jr.")
    await store.send(\.destination.addContact.saveButtonTapped)
    await store.skipReceivedActions()
    store.assert {
      $0.contacts = [
        Contact(id: UUID(0), name: "Blob Jr.")
      ]
      $0.destination = nil
    }
  }
}
