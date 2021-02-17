import CasePaths
import ComposableArchitecture
import SwiftUI

struct Item: Identifiable, Equatable {
  var id: String
  var name: String
}

struct Main {
}

extension Main {
  struct State: Equatable {
    var children: [Child.State]
  }
}

extension Main {
  enum Action {
    case child(id: Child.State.ID, action: Child.Action)
  }
}

extension Main {
  struct Environment {
    let loadItem: (Item) -> Effect<Item, Never>
  }
}

extension Main {
  struct View: SwiftUI.View {
    let store: Store<State, Action>

    var body: some SwiftUI.View {
      ScrollView {
        LazyVGrid(columns: [.init(), .init()]) {
          _ForEachStore(
            store.scope(
              state: \.children,
              action: Action.child(id:action:)
            )
          ) { childStore in
            Child.View(
              store: childStore
            )
          }
        }
      }
    }
  }
}

extension Main {
  static let localReducer: Reducer<State, Action, Environment> = .init { state, action, environment in
    return .none
  }
  static let reducer: Reducer<State, Action, Environment> = .combine(
    Child.reducer._forEach(
      state: \.children,
      action: /Action.child(id:action:),
      environment: { env in
        .init(
          loadItem: env.loadItem
        )
      }
    ),
    localReducer
  )
}

struct Child {
}

extension Child {
  struct State: Equatable, Identifiable {
    var id: String { item.id }
    var item: Item
  }
}

extension Child {
  enum Action {
    case loadItemContent
    case itemLoaded(Item)
  }
}

extension Child {
  struct Environment {
    let loadItem: (Item) -> Effect<Item, Never>
  }
}

extension Child {
  struct View: SwiftUI.View {
    let store: Store<State, Action>

    var body: some SwiftUI.View {
      WithViewStore(store) { viewStore in
        Text("\(viewStore.item.id) - \(viewStore.item.name)")
          .onAppear {
            viewStore.send(.loadItemContent)
          }
      }
    }
  }
}

extension Child {
  static let reducer: Reducer<State, Action, Environment> = .init { state, action, environment in
    switch action {
    case .loadItemContent:
      return environment
        .loadItem(state.item)
        .map(Action.itemLoaded)
    case .itemLoaded(let item):
      state.item = item
    }
    return .none
  }
}
