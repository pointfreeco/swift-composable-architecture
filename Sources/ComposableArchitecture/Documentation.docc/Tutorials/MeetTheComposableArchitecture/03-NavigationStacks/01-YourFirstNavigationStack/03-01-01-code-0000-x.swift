struct Contact: Equatable, Identifiable {
  let id: UUID
  var friends: [Contact]
  var name: String
}
