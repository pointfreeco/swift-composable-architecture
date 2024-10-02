import ComposableArchitecture
import Testing

@testable import ContactsApp

@MainActor
struct ContactsFeatureTests {
  @Test
  func addFlow() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    }
    
    await store.send(.addButtonTapped) {
      $0.destination = .addContact(
        AddContactFeature.State(
        )
      )
    }
  }
}
