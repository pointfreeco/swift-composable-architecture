import Combine
import ComposableArchitecture
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

struct FavoriteState<ID>: Equatable, Identifiable where ID: Hashable {
  var alert: AlertState<FavoriteAction>?
  let id: ID
  var isFavorite: Bool
}

enum FavoriteAction: Equatable {
  case alertDismissed
  case buttonTapped
  case response(Result<Bool, FavoriteError>)
}

struct FavoriteEnvironment<ID> {
  var request: (ID, Bool) -> Effect<Bool, Error>
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

/// A cancellation token that cancels in-flight favoriting requests.
struct FavoriteCancelId<ID>: Hashable where ID: Hashable {
  var id: ID
}

/// A wrapper for errors that occur when favoriting.
struct FavoriteError: Equatable, Error, Identifiable {
  let error: NSError
  var localizedDescription: String { self.error.localizedDescription }
  var id: String { self.error.localizedDescription }
  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

extension Reducer {
  /// Enhances a reducer with favoriting logic.
  func favorite<ID>(
    state: WritableKeyPath<State, FavoriteState<ID>>,
    action: CasePath<Action, FavoriteAction>,
    environment: @escaping (Environment) -> FavoriteEnvironment<ID>
  ) -> Reducer where ID: Hashable {
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

          return environment.request(state.id, state.isFavorite)
            .receive(on: environment.mainQueue)
            .mapError { FavoriteError(error: $0 as NSError) }
            .catchToEffect(FavoriteAction.response)
            .cancellable(id: FavoriteCancelId(id: state.id), cancelInFlight: true)

        case let .response(.failure(error)):
          state.alert = .init(title: TextState(error.localizedDescription))
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

struct FavoriteButton<ID>: View where ID: Hashable {
  let store: Store<FavoriteState<ID>, FavoriteAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Button(action: { viewStore.send(.buttonTapped) }) {
        Image(systemName: viewStore.isFavorite ? "heart.fill" : "heart")
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
  var favorite: (EpisodeState.ID, Bool) -> Effect<Bool, Error>
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

struct EpisodeView: View {
  let store: Store<EpisodeState, EpisodeAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
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
  environment: { FavoriteEnvironment(request: $0.favorite, mainQueue: $0.mainQueue) }
)

struct EpisodesState: Equatable {
  var episodes: IdentifiedArrayOf<EpisodeState> = []
}

enum EpisodesAction: Equatable {
  case episode(id: EpisodeState.ID, action: EpisodeAction)
}

struct EpisodesEnvironment {
  var favorite: (UUID, Bool) -> Effect<Bool, Error>
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let episodesReducer: Reducer<EpisodesState, EpisodesAction, EpisodesEnvironment> =
  episodeReducer.forEach(
    state: \EpisodesState.episodes,
    action: /EpisodesAction.episode(id:action:),
    environment: { EpisodeEnvironment(favorite: $0.favorite, mainQueue: $0.mainQueue) }
  )

struct EpisodesView: View {
  let store: Store<EpisodesState, EpisodesAction>

  var body: some View {
    Form {
      Section(header: Text(template: readMe, .caption)) {
        ForEachStore(
          self.store.scope(state: \.episodes, action: EpisodesAction.episode(id:action:))
        ) { rowStore in
          EpisodeView(store: rowStore)
            .buttonStyle(.borderless)
        }
      }
    }
    .navigationBarTitle("Favoriting")
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
            favorite: favorite(id:isFavorite:),
            mainQueue: .main
          )
        )
      )
    }
  }
}

func favorite<ID>(id: ID, isFavorite: Bool) -> Effect<Bool, Error> {
  Effect.future { callback in
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if .random(in: 0...1) > 0.25 {
        callback(.success(isFavorite))
      } else {
        callback(
          .failure(
            NSError(
              domain: "co.pointfree", code: -1,
              userInfo: [NSLocalizedDescriptionKey: "Something went wrong!"]
            )
          )
        )
      }
    }
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
