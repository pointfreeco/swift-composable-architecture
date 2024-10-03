import ComposableArchitecture
import SwiftUI

@Reducer
struct PlayerFormFeature {
  @ObservableState
  struct State: Equatable {
    var player: Player
    var focus: Focus? = .name

    enum Focus {
      case name
      case score
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case cancelButtonTapped
    case saveButtonTapped
  }

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.dismiss) var dismiss

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none
      case .cancelButtonTapped:
        return .run { _ in
          await dismiss()
        }
      case .saveButtonTapped:
        return .run { [player = state.player] _ in
          try await database.write { db in
            var player = player
            try player.save(db)
          }
          await dismiss()
        }
      }
    }
  }
}

struct PlayerFormView: View {
  @Bindable var store: StoreOf<PlayerFormFeature>
  @FocusState private var focus: PlayerFormFeature.State.Focus?

  var body: some View {
    Form {
      LabeledContent {
        TextField(text: $store.player.name) {}
          .textInputAutocapitalization(.words)
          .autocorrectionDisabled()
          .submitLabel(.next)
          .focused($focus, equals: .name)
          .labelsHidden()
          .onSubmit {
            store.focus = .score
          }
      } label: {
        Text("Name").foregroundStyle(.secondary)
      }

      LabeledContent {
        TextField(value: $store.player.score, format: .number) {}
          .keyboardType(.numberPad)
          .focused($focus, equals: .score)
          .labelsHidden()
      } label: {
        Text("Score").foregroundStyle(.secondary)
      }
    }
    .bind($store.focus, to: $focus)
  }
}
