import ComposableArchitecture
import Foundation
import Testing

@testable import ContactsApp

@MainActor
struct ContactsFeatureTests {
  @Test
  func deleteContact() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
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
