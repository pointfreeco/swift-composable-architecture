struct ContactsView: View {
  let store: StoreOf<ContactsFeature>

  var body: some View {
    NavigationStackStore(self.store.scope(state: \.path, action: { .path($0) })) {
      WithViewStore(self.store, observe: \.contacts) { viewStore in
        List {
          ForEach(viewStore.state) { contact in
            NavigationLink(state: ContactDetailFeature.State(contact: contact)) {
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
            .buttonStyle(.borderless)
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
      state: \.addContact,
      action: { .addContact($0) }
    ) { addContactStore in
      NavigationStack {
        AddContactView(store: addContactStore)
      }
    }
    .alert(
      store: self.store.scope(state: \.$destination, action: { .destination($0) }),
      state: \.alert,
      action: { .alert($0) }
    )
  }
}
