import ComposableArchitecture
import SwiftUI

struct ContactDetailView: View {
  let store: StoreOf<ContactDetailFeature>
  
  var body: some View {
    Form {
    }
    .navigationTitle(Text(store.contact.name))
  }
}

#Preview {
  NavigationStack {
    ContactDetailView(
      store: Store(
        initialState: ContactDetailFeature.State(
          contact: Contact(id: UUID(), name: "Blob")
        )
      ) {
        ContactDetailFeature()
      }
    )
  }
}
