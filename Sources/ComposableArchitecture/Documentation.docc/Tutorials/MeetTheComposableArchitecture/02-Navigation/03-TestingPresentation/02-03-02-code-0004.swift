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
  }
}
