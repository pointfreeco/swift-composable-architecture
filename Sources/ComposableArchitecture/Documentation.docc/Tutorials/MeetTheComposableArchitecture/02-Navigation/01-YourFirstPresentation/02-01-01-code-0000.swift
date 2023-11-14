import Foundation
import ComposableArchitecture

struct Contact: Equatable, Identifiable {
  let id: UUID
  var name: String
}

@Reducer
struct ContactsFeature {
  struct State: Equatable {
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action {
    case addButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        // TODO: Handle action
        return .none
      }
    }
  }
}
