import ComposableArchitecture
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
          contact: Contact(id: ???, name: "")
        )
      )
    }
  }
}
