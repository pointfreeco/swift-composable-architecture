import Combine
import ComposableArchitecture
import Foundation
import SwiftUI

private let readMe = """
  This screen demonstrates how one can create reusable components in the Composable Architecture.

  It introduces the domain, logic, and view around "favoriting" something, which is considerably \
  complex.

  A feature can give itself the ability to "favorite" part of its state by embedding the domain of \
  favoriting, using the `favorite` higher-order reducer, and passing an appropriately scoped store \
  to `FavoriteButton`.

  Tapping the favorite button on a row will instantly reflect in the UI and fire off an effect to \
  do any necessary work, like writing to a database or making an API request. We have simulated a \
  request that takes 1 second to run and may fail 25% of the time. Failures result in rolling back \
  favorite state and rendering an alert.
  """

// MARK: - Favorite domain

struct FavoriteState<ID: Hashable>: Equatable, Identifiable {
  var alert: AlertState<FavoriteAction>?
  let id: ID
  var isFavorite: Bool
}

enum FavoriteAction: Equatable {
  case alertDismissed
  case buttonTapped
  case response(TaskResult<Bool>)
}

struct FavoriteEnvironment<ID: Sendable> {
  var request: @Sendable (ID, Bool) async throws -> Bool
}

/// A cancellation token that cancels in-flight favoriting requests.
struct FavoriteCancelID<ID: Hashable>: Hashable {
  var id: ID
}

extension Reducer {
  /// Enhances a reducer with favoriting logic.
  func favorite<ID: Hashable>(
    state: WritableKeyPath<State, FavoriteState<ID>>,
    action: CasePath<Action, FavoriteAction>,
    environment: @escaping (Environment) -> FavoriteEnvironment<ID>
  ) -> Self {
    .combine(
      self,
      Reducer<FavoriteState<ID>, FavoriteAction, FavoriteEnvironment> {
        state, action, environment in
        switch action {
        case .alertDismissed:
          state.alert = nil
          state.isFavorite.toggle()
          return .none

        case .buttonTapped:
          state.isFavorite.toggle()

          return .task { [id = state.id, isFavorite = state.isFavorite] in
            await .response(TaskResult { try await environment.request(id, isFavorite) })
          }
          .cancellable(id: FavoriteCancelID(id: state.id), cancelInFlight: true)

        case let .response(.failure(error)):
          state.alert = AlertState(title: TextState(error.localizedDescription))
          return .none

        case let .response(.success(isFavorite)):
          state.isFavorite = isFavorite
          return .none
        }
      }
      .pullback(state: state, action: action, environment: environment)
    )
  }
}

struct FavoriteButton<ID: Hashable>: View {
  let store: Store<FavoriteState<ID>, FavoriteAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Button {
        viewStore.send(.buttonTapped)
      } label: {
        Image(systemName: "heart")
          .symbolVariant(viewStore.isFavorite ? .fill : .none)
      }
      .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
    }
  }
}

// MARK: Feature domain -

struct EpisodeState: Equatable, Identifiable {
  var alert: AlertState<FavoriteAction>?
  let id: UUID
  var isFavorite: Bool
  let title: String

  var favorite: FavoriteState<ID> {
    get { .init(alert: self.alert, id: self.id, isFavorite: self.isFavorite) }
    set { (self.alert, self.isFavorite) = (newValue.alert, newValue.isFavorite) }
  }
}

enum EpisodeAction: Equatable {
  case favorite(FavoriteAction)
}

struct EpisodeEnvironment {
  var favorite: @Sendable (EpisodeState.ID, Bool) async throws -> Bool
}

struct EpisodeView: View {
  let store: Store<EpisodeState, EpisodeAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack(alignment: .firstTextBaseline) {
        Text(viewStore.title)

        Spacer()

        FavoriteButton(
          store: self.store.scope(state: \.favorite, action: EpisodeAction.favorite))
      }
    }
  }
}

let episodeReducer = Reducer<EpisodeState, EpisodeAction, EpisodeEnvironment>.empty.favorite(
  state: \.favorite,
  action: /EpisodeAction.favorite,
  environment: { FavoriteEnvironment(request: $0.favorite) }
)

struct EpisodesState: Equatable {
  var episodes: IdentifiedArrayOf<EpisodeState> = []
}

enum EpisodesAction: Equatable {
  case episode(id: EpisodeState.ID, action: EpisodeAction)
}

struct EpisodesEnvironment {
  var favorite: @Sendable (UUID, Bool) async throws -> Bool
}

let episodesReducer: Reducer<EpisodesState, EpisodesAction, EpisodesEnvironment> =
  episodeReducer.forEach(
    state: \EpisodesState.episodes,
    action: /EpisodesAction.episode(id:action:),
    environment: { EpisodeEnvironment(favorite: $0.favorite) }
  )

struct EpisodesView: View {
  let store: Store<EpisodesState, EpisodesAction>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      ForEachStore(
        self.store.scope(state: \.episodes, action: EpisodesAction.episode(id:action:))
      ) { rowStore in
        EpisodeView(store: rowStore)
      }
      .buttonStyle(.borderless)
    }
    .navigationTitle("Favoriting")
  }
}

struct EpisodesView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EpisodesView(
        store: Store(
          initialState: EpisodesState(
            episodes: .mocks
          ),
          reducer: episodesReducer,
          environment: EpisodesEnvironment(
            favorite: favorite(id:isFavorite:)
          )
        )
      )
    }
  }
}

struct FavoriteError: LocalizedError {
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

extension IdentifiedArray where ID == EpisodeState.ID, Element == EpisodeState {
  static let mocks: Self = [
    EpisodeState(id: UUID(), isFavorite: false, title: "Functions"),
    EpisodeState(id: UUID(), isFavorite: false, title: "Side Effects"),
    EpisodeState(id: UUID(), isFavorite: false, title: "Algebraic Data Types"),
    EpisodeState(id: UUID(), isFavorite: false, title: "DSLs"),
    EpisodeState(id: UUID(), isFavorite: false, title: "Parsers"),
    EpisodeState(id: UUID(), isFavorite: false, title: "Composable Architecture"),
  ]
}
