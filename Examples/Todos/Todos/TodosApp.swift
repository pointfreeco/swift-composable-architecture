//import ComposableArchitecture
//import SwiftUI
//
//@main
//struct TodosApp: App {
//  var body: some Scene {
//    WindowGroup {
//      AppView(
//        store: Store(
//          initialState: Todos.State(),
//          reducer: Todos().debug()
//        )
//      )
//    }
//  }
//}


import ComposableArchitecture
import SwiftUI

import Combine

var c: AnyCancellable?

@main
struct ViewStoreUpdatesApp: App {
  let store = Store(initialState: .init(), reducer: ReducerFeature())
  let reducer2Store = Store(initialState: .init(), reducer: Reducer2Feature())

  let scopedStore: Store<Reducer3Feature.State, Reducer3Feature.Action>

  init() {
    scopedStore = store
      .scope(state: \.reducer2, action: ReducerFeature.Action.reducer2)
      .scope(state: \.reducer3, action: Reducer2Feature.Action.reducer3)

    c = ViewStore(scopedStore)
      .publisher
      .sink {
        print("HELLO", $0)
        print("!!!!")
      }

  }

  var body: some Scene {
    WindowGroup {
      // Doesn't Work
      ContentView(
        store: scopedStore
//          store
//          .scope(state: \.reducer2, action: ReducerFeature.Action.reducer2)
//          .scope(state: \.reducer3, action: Reducer2Feature.Action.reducer3)
      )

//      ContentView(
//        store: store
//          .scope(state: \.reducer2.reducer3, action: { .reducer2(.reducer3($0)) })
//      )
//
//      // Works
//      ContentView(
//        store: reducer2Store
//          .scope(state: \.reducer3, action: Reducer2Feature.Action.reducer3)
//      )
    }
  }
}

struct ReducerFeature: ReducerProtocol {
  struct State: Equatable {
    var reducer2: Reducer2Feature.State

    init() {
      self.reducer2 = .init()
    }
  }

  enum Action: Equatable {
    case reducer2(Reducer2Feature.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.reducer2, action: /Action.reducer2) {
      Reducer2Feature()
    }
    Reduce { state, action in
      switch action {
      case .reducer2:
        return .none
      }
    }
  }
}

struct Reducer2Feature: ReducerProtocol {
  struct State: Equatable {
    var reducer3: Reducer3Feature.State
    init() {
      reducer3 = .init()
    }
  }

  enum Action: Equatable {
    case reducer3(Reducer3Feature.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.reducer3, action: /Action.reducer3) {
      Reducer3Feature()
    }
    Reduce { state, action in
      switch action {
      case .reducer3:
        return .none
      }
    }
  }
}

struct Reducer3Feature: ReducerProtocol {
  struct State: Equatable {
    var isLoading: Bool

    init() {
      isLoading = false
    }
  }

  enum Action: Equatable {
    case loaded
    case task
  }

  var body: Reduce<State, Action> {
    Reduce { state, action in
      switch action {
      case .loaded:
        state.isLoading = false
        return .none

      case .task:
        state.isLoading = true
        return .task {
          return .loaded
        }
      }
    }
  }
}

struct ContentView: View {
  struct ViewState: Equatable {
    let isLoading: Bool

    init(_ state: Reducer3Feature.State) {
      isLoading = state.isLoading
    }
  }

  let store: StoreOf<Reducer3Feature>

  init(store: StoreOf<Reducer3Feature>) {
    self.store = store
  }

  var body: some View {
    WithViewStore(store, observe: ViewState.init) { viewStore in
      VStack {
        if viewStore.isLoading {
          ProgressView()
        } else {
          VStack {
            Image(systemName: "globe")
              .imageScale(.large)
              .foregroundColor(.accentColor)
            Text("Hello, world!")
          }
          .padding()
        }
      }
      .task {
        await viewStore.send(.task).finish()
      }
    }
  }
}
