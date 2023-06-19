struct ContentView: View {
  let store: StoreOf<ContactsFeature>

  var body: some View {
    NavigationStackStore(self.store.scope(state: \.path, action: { .path($0) })) {
      WithViewStore(self.store, observe: \.contacts) { viewStore in
        List {
          ForEach(viewStore.state) { contact in
              HStack {
                Text(contact.name)
                Spacer()
                Button {
                  viewStore.send(.deleteButtonTapped(id: contact.id))
                } label: {
                  Image(systemName: "trash")
                    .foregroundColor(.red)
                }
              }
          }
        }
        .navigationTitle("Contacts")
        .toolbar {
          ToolbarItem {
            Button {
              viewStore.send(.addButtonTapped)
            } label: {
              Image(systemName: "plus")
            }
          }
        }
      }
    } destination: { store in
      ContactDetailView(store: store)
    }
    .sheet(
      store: self.store.scope(state: \.$destination, action: { .destination($0) }),
      state: /ContactsFeature.Destination.State.addContact,
      action: ContactsFeature.Destination.Action.addContact
    ) { addContactStore in
      NavigationStack {
        AddContactView(store: addContactStore)
      }
    }
    .alert(
      store: self.store.scope(state: \.$destination, action: { .destination($0) }),
      state: /ContactsFeature.Destination.State.alert,
      action: ContactsFeature.Destination.Action.alert
    )
  }
}
