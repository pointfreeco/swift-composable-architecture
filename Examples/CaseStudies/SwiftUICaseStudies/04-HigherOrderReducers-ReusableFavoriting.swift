import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how one can create reusable components in the Composable Architecture.

  It introduces the domain, logic, and view around "favoriting" something, which is considerably \
  complex.

  A feature can give itself the ability to "favorite" part of its state by embedding the domain of \
  favoriting, using the `Favoriting` reducer, and passing an appropriately scoped store to \
  `FavoriteButton`.

  Tapping the favorite button on a row will instantly reflect in the UI and fire off an effect to \
  do any necessary work, like writing to a database or making an API request. We have simulated a \
  request that takes 1 second to run and may fail 25% of the time. Failures result in rolling back \
  favorite state and rendering an alert.
  """

// MARK: - Reusable favorite component

struct FavoritingState<ID: Hashable & Sendable>: Equatable {
  @PresentationState var alert: AlertState<FavoritingAction.Alert>?
  let id: ID
  var isFavorite: Bool
}

enum FavoritingAction: Equatable {
  case alert(PresentationAction<Alert>)
  case buttonTapped
  case response(TaskResult<Bool>)

  enum Alert: Equatable {}
}

struct Favoriting<ID: Hashable & Sendable>: Reducer {
  let favorite: @Sendable (ID, Bool) async throws -> Bool

  private struct CancelID: Hashable {
    let id: AnyHashable
  }

  func reduce(
    into state: inout FavoritingState<ID>, action: FavoritingAction
  ) -> Effect<FavoritingAction> {
    switch action {
    case .alert(.dismiss):
      state.alert = nil
      state.isFavorite.toggle()
      return .none

    case .buttonTapped:
      state.isFavorite.toggle()

      return .run { [id = state.id, isFavorite = state.isFavorite, favorite] send in
        await send(.response(TaskResult { try await favorite(id, isFavorite) }))
      }
      .cancellable(id: CancelID(id: state.id), cancelInFlight: true)

    case let .response(.failure(error)):
      state.alert = AlertState { TextState(error.localizedDescription) }
      return .none

    case let .response(.success(isFavorite)):
      state.isFavorite = isFavorite
      return .none
    }
  }
}

struct FavoriteButton<ID: Hashable & Sendable>: View {
  let store: Store<FavoritingState<ID>, FavoritingAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Button {
        viewStore.send(.buttonTapped)
      } label: {
        Image(systemName: "heart")
          .symbolVariant(viewStore.isFavorite ? .fill : .none)
      }
      .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
    }
  }
}

// MARK: - Feature domain

struct Episode: Reducer {
  struct State: Equatable, Identifiable {
    var alert: AlertState<FavoritingAction.Alert>?
    let id: UUID
    var isFavorite: Bool
    let title: String

    var favorite: FavoritingState<ID> {
      get { .init(alert: self.alert, id: self.id, isFavorite: self.isFavorite) }
      set { (self.alert, self.isFavorite) = (newValue.alert, newValue.isFavorite) }
    }
  }
  enum Action: Equatable {
    case favorite(FavoritingAction)
  }
  let favorite: @Sendable (UUID, Bool) async throws -> Bool

  var body: some Reducer<State, Action> {
    Scope(state: \.favorite, action: /Action.favorite) {
      Favoriting(favorite: self.favorite)
    }
  }
}

// MARK: - Feature view

struct EpisodeView: View {
  let store: StoreOf<Episode>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack(alignment: .firstTextBaseline) {
        Text(viewStore.title)

        Spacer()

        FavoriteButton(
          store: self.store.scope(
            state: \.favorite,
            action: Episode.Action.favorite
          )
        )
      }
    }
  }
}

struct Episodes: Reducer {
  struct State: Equatable {
    var episodes: IdentifiedArrayOf<Episode.State> = []
  }
  enum Action: Equatable {
    case episode(id: Episode.State.ID, action: Episode.Action)
  }
  let favorite: @Sendable (UUID, Bool) async throws -> Bool

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      .none
    }
    .forEach(\.episodes, action: /Action.episode) {
      Episode(favorite: self.favorite)
    }
  }
}

struct EpisodesView: View {
  let store: StoreOf<Episodes>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      ForEachStore(
        self.store.scope(
          state: \.episodes,
          action: Episodes.Action.episode(id:action:)
        )
      ) { rowStore in
        EpisodeView(store: rowStore)
      }
      .buttonStyle(.borderless)
    }
    .navigationTitle("Favoriting")
  }
}

// MARK: - SwiftUI previews

struct EpisodesView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EpisodesView(
        store: Store(
          initialState: Episodes.State(
            episodes: .mocks
          )
        ) {
          Episodes(favorite: favorite(id:isFavorite:))
        }
      )
    }
  }
}

struct FavoriteError: LocalizedError, Equatable {
  var errorDescription: String? {
    "Favoriting failed."
  }
}

@Sendable func favorite<ID>(id: ID, isFavorite: Bool) async throws -> Bool {
  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
  if .random(in: 0...1) > 0.25 {
    return isFavorite
  } else {
    throw FavoriteError()
  }
}

extension IdentifiedArray where ID == Episode.State.ID, Element == Episode.State {
  static let mocks: Self = [
    Episode.State(id: UUID(), isFavorite: false, title: "Functions"),
    Episode.State(id: UUID(), isFavorite: false, title: "Side Effects"),
    Episode.State(id: UUID(), isFavorite: false, title: "Algebraic Data Types"),
    Episode.State(id: UUID(), isFavorite: false, title: "DSLs"),
    Episode.State(id: UUID(), isFavorite: false, title: "Parsers"),
    Episode.State(id: UUID(), isFavorite: false, title: "Composable Architecture"),
  ]
}
