import ComposableArchitecture
import GRDB
import SwiftUI

@Reducer
struct PlayersListFeature {
  @Reducer
  enum Destination {
    case add(PlayerFormFeature)
    case edit(PlayerFormFeature)
  }

  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    var editMode: EditMode
    var order: PlayersRequest.Order {
      didSet {
        _players = SharedReader(wrappedValue: [], .players(order: order))
      }
    }
    @SharedReader var players: [Player]

    init(
      editMode: EditMode = .inactive,
      order: PlayersRequest.Order = .score
    ) {
      self.editMode = editMode
      self.order = order
      self._players = SharedReader(wrappedValue: [], .players(order: order))
    }
  }

  enum Action {
    case addPlayerButtonTapped
    case deletePlayers(offsets: IndexSet)
    case deleteAllPlayersButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case editModeChanged(EditMode)
    case editPlayerButtonTapped(Player)
    case toggleOrderingButtonTapped
  }

  @Dependency(\.defaultDatabase) var database

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .addPlayerButtonTapped:
        state.destination = .add(PlayerFormFeature.State(player: Player()))
        return .none

      case .deletePlayers(let offsets):
        let playerIds = offsets.compactMap { state.players[$0].id }
        if playerIds.count == state.players.count {
          state.editMode = .inactive
        }
        return .run { _ in
          try database.write { db in
            _ = try Player.deleteAll(db, keys: playerIds)
          }
        }

      case .deleteAllPlayersButtonTapped:
        state.editMode = .inactive
        return .run { _ in
          try database.write { db in
            _ = try Player.deleteAll(db)
          }
        }

      case .destination(.dismiss):
        if case let .edit(editState) = state.destination {
          return .run { _ in
            _ = try database.write { db in
//              var player = editState.player
//              try player.save(db)
//              try player.insert(db)
              try editState.player.inserted(db)
            }
          }
        }
        return .none

      case .destination:
        return .none

      case .editModeChanged(let editMode):
        state.editMode = editMode
        return .none

      case .editPlayerButtonTapped(let player):
        state.destination = .edit(PlayerFormFeature.State(player: player))
        return .none

      case .toggleOrderingButtonTapped:
        switch state.order {
        case .name:
          state.order = .score
          return .none
        case .score:
          state.order = .name
          return .none
        }
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension PlayersListFeature.Destination.State: Equatable {}

extension PersistenceReaderKey where Self == GRDBQueryKey<PlayersRequest> {
  static func players(order: PlayersRequest.Order) -> Self {
    .query(PlayersRequest(order: order))
  }
}

struct PlayersRequest: GRDBQuery {
  enum Order {
    case name
    case score
  }

  let order: Order

  func fetch(_ db: Database) throws -> [Player] {
    let order: [any SQLOrderingTerm] = switch order {
    case .name:
      [
        Column("name").collating(.localizedCaseInsensitiveCompare)
      ]
    case .score:
      [
        Column("score").desc,
        Column("name").collating(.localizedCaseInsensitiveCompare)
      ]
    }

    return try Player.all()
      .order(order)
      .fetchAll(db)
  }
}

struct PlayersListView: View {
  @Bindable var store: StoreOf<PlayersListFeature>

  var body: some View {
    NavigationStack {
      Group {
        if store.players.isEmpty {
          ContentUnavailableView {
            Label("The team is empty!", systemImage: "person.slash")
          } actions: {
            Button("Add Player") {
              store.send(.addPlayerButtonTapped)
            }
            .buttonStyle(.borderedProminent)
          }
          .navigationTitle("")
        } else {
          List {
            ForEach(store.players, id: \.id) { player in
              Button {
                store.send(.editPlayerButtonTapped(player))
              } label: {
                PlayerRow(player: player)
              }
            }
            .onDelete { offsets in
              store.send(.deletePlayers(offsets: offsets))
            }
          }
          .animation(.default, value: store.players)
          .listStyle(.plain)
          .navigationTitle("\(store.players.count) Players")
          .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
              Button {
                store.send(.addPlayerButtonTapped)
              } label: {
                Image(systemName: "plus")
              }
              EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                store.send(.toggleOrderingButtonTapped)
              } label: {
                HStack {
                  switch store.order {
                  case .name:
                    Text("Name")
                    Image(systemName: "arrowtriangle.up.fill")
                      .imageScale(.medium)
                  case .score:
                    Text("Score")
                    Image(systemName: "arrowtriangle.down.fill")
                      .imageScale(.medium)
                  }
                }
              }
            }
          }
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .bottomBar) {
          Button {
            store.send(.deleteAllPlayersButtonTapped)
          } label: {
            Image(systemName: "trash")
          }
          // Spacer()
          // refreshButton
          // Spacer()
          // tornadoButton
        }
      }
      .environment(\.editMode, $store.editMode.sending(\.editModeChanged))
      .navigationDestination(
        item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
      ) { store in
        PlayerFormView(store: store)
          .navigationTitle(store.player.name)
      }
    }
    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
      NavigationStack {
        PlayerFormView(store: store)
          .navigationTitle("New Player")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { store.send(.cancelButtonTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Save") { store.send(.saveButtonTapped) }
            }
          }
      }
    }
  }
}

struct PlayerRow: View {
  var player: Player

  var body: some View {
    HStack {
      Group {
        if player.name.isEmpty {
          Text("Anonymous").italic()
        } else {
          Text(player.name)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text("\(player.score) points")
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
  }
}
