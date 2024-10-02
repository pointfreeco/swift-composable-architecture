import ComposableArchitecture
import Foundation
import Testing

@testable import ContactsApp

@MainActor
struct ContactsFeatureTests {
  @Test
  func addFlow() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    } withDependencies: {
      $0.uuid = .incrementing
    }
    
    await store.send(.addButtonTapped) {
      $0.destination = .addContact(
        AddContactFeature.State(
          contact: Contact(id: UUID(0), name: "")
        )
      )
    }
    await store.send(\.destination.addContact.setName, "Blob Jr.") {
      $0.destination?.addContact?.contact.name = "Blob Jr."
    }
    await store.send(\.destination.addContact.saveButtonTapped)
    await store.receive(
      \.destination.addContact.delegate.saveContact,
      Contact(id: UUID(0), name: "Blob Jr.")
    ) {
    }
  }
}
