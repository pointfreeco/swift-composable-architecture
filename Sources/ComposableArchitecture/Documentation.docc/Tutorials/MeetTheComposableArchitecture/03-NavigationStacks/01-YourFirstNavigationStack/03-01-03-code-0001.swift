import SwiftUI

struct ContactDetailView: View {
  let store: StoreOf<ContactDetailFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        if !viewStore.contact.friends.isEmpty {
          Section {
            ForEach(viewStore.contact.friends) { friend in
              NavigationLink(state: ContactDetailFeature.State(contact: friend)) {
                Text(friend.name)
              }
            }
          } header: {
            Text("Friends")
          }
        }
      }
      .navigationBarTitle(Text(viewStore.contact.name))
    }
  }
}

struct ContactDetailPreviews: PreviewProvider {
  static var previews: some View {
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
}
