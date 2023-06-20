import Foundation
import ComposableArchitecture

struct Contact: Equatable, Identifiable {
  let id: UUID
  var name: String
}

struct ContactsFeature: Reducer {
  struct State: Equatable {
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action: Equatable {
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
