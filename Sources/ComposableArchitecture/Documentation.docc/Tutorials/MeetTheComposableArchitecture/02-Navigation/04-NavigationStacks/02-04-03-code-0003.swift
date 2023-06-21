import SwiftUI

struct ContactDetailView: View {
  let store: StoreOf<ContactDetailFeature>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Button("Delete") {
          viewStore.send(.deleteButtonTapped)
        }
      }
      .navigationBarTitle(Text(viewStore.contact.name))
    }
    .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
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
