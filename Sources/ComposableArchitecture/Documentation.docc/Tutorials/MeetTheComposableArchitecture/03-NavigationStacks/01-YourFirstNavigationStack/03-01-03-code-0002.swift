struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: Store(
        initialState: ContactsFeature.State(
          contacts: [
            Contact(
              id: UUID(),
              friends: [
                Contact(id: UUID(), name: "Mary"),
                Contact(id: UUID(), name: "James"),
                Contact(id: UUID(), name: "Nicole"),
              ],
              name: "Blob"
            ),
            Contact(
              id: UUID(),
              friends: [
                Contact(id: UUID(), name: "Taylor"),
                Contact(id: UUID(), name: "Julia"),
              ],
              name: "Blob Jr"
            ),
            Contact(
              id: UUID(),
              friends: [
                Contact(id: UUID(), name: "Sam"),
                Contact(id: UUID(), name: "Joy"),
                Contact(id: UUID(), name: "Daisy"),
              ],
              name: "Blob Sr"
            ),
          ]
        ),
        reducer: ContactsFeature()
      )
    )
  }
}
