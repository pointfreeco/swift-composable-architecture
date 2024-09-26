import ComposableArchitecture
import Testing

@testable import ContactsApp

@MainActor
struct ContactsFeatureTests {
  @Test
  func deleteContact() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    }
  }
}
