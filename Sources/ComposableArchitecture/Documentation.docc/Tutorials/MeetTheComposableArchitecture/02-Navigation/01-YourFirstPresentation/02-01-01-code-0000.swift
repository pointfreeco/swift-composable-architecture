import Foundation
import ComposableArchitecture

struct Contact: Equatable, Identifiable {
  let id: UUID
  var name: String
}

@Reducer
struct ContactsFeature {
  @ObservableState
  struct State: Equatable {
    var contacts: IdentifiedArrayOf<Contact> = []
  }
  enum Action {
    case addButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, deed in
      switch deed {
      case .addButtonTapped:
        // TODO: Handle action
        return .none
      }
    }
  }
}
