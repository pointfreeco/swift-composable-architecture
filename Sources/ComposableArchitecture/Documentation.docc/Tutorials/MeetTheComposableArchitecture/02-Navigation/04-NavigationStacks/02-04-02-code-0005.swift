struct ContactsView: View {
  @Bindable var store: StoreOf<ContactsFeature>
  
  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      List {
        ForEach(store.contacts) { contact in
          NavigationLink(state: ContactDetailFeature.State(contact: contact)) {
            HStack {
              Text(contact.name)
              Spacer()
              Button {
                store.send(.deleteButtonTapped(id: contact.id))
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
            store.send(.addButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    } destination: { store in
      ContactDetailView(store: store)
    }
    .sheet(
      store: $store.scope(state: \.destination?.addContact, action: \.destination.addContact)
    ) { addContactStore in
      NavigationStack {
        AddContactView(store: addContactStore)
      }
    }
    .alert(store: store.scope(state: \.$destination.alert, action: \.destination.alert))
  }
}
