import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      //RootView()
      ContentView()
    }
  }
}


import SwiftUI
import ComposableArchitecture


//@inlinable
//public func _$isIdentityEqual<ID, T: ObservableState>(
//  _ lhs: IdentifiedArray<ID, T>,
//  _ rhs: IdentifiedArray<ID, T>
//) -> Bool {
//  false
//}

@Reducer
struct MainFeature {
  @ObservableState
  struct State {
    var childArray: IdentifiedArrayOf<ChildFeature.State>
    var childSolo: ChildFeature.State?

    init() {
      childSolo = ChildFeature.State(id: "1", count: 0)
      // It's important to start with non empty array.
      childArray = [ChildFeature.State(id: "1", count: 0)]
    }
  }

  enum Action {
    case setAnotherIDs
    case getBackToInitialIDsWithAnotherCount
    case resetToInitialIDs
    case childArray(IdentifiedActionOf<ChildFeature>)
    case childSolo(ChildFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .setAnotherIDs:
        // Update ID
        state.childSolo = ChildFeature.State(id: "2", count: 0)
        state.childArray = [ChildFeature.State(id: "2", count: 0)]
        return .none

      case .getBackToInitialIDsWithAnotherCount:
        // Go back to the initial ID with a different count
        state.childSolo = ChildFeature.State(id: "1", count: 10)
        state.childArray = [ChildFeature.State(id: "1", count: 10)]
        return .none

      case .resetToInitialIDs:
        // Set the same ID as in the previous action, but with a count of 0
        // After this step, the child stores in childArray stopped working.
        state.childSolo = ChildFeature.State(id: "1", count: 0)
        state.childArray = [ChildFeature.State(id: "1", count: 0)]
        return .none

      case .childArray:
        return .none

      case .childSolo:
        return .none
      }
    }
    .ifLet(\.childSolo, action: \.childSolo) {
      ChildFeature()
    }
    .forEach(\.childArray, action: \.childArray) {
      ChildFeature()
    }
  }
}

@Reducer
struct ChildFeature {
  @ObservableState
  struct State: Identifiable {
    let id: String
    var count: Int
  }

  enum Action {
    case plus
    case minus
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .plus:
        state.count += 1
        return .none

      case .minus:
        state.count -= 1
        return .none
      }
    }
  }
}

struct ChildView: View {
  let store: StoreOf<ChildFeature>

  var body: some View {
    VStack {
      Text("id: " + store.id)

      HStack {
        Button("Minus") {
          store.send(.minus)
        }

        Text(store.count.description)

        Button("Plus") {
          store.send(.plus)
        }
      }
      .frame(height: 50)
      .buttonStyle(.borderedProminent)
    }
  }
}

struct MainView: View {
  let store: StoreOf<MainFeature>

  var body: some View {
    ScrollView {
      VStack {
        Button("setAnotherIDs") {
          store.send(.setAnotherIDs)
        }

        Button("getBackToInitialIDsWithAnotherCount") {
          store.send(.getBackToInitialIDsWithAnotherCount)
        }

        Button("resetToInitialIDs (not working)") {
          store.send(.resetToInitialIDs)
        }

        Color.red.frame(height: 10)

//        Text("Child solo:")
//        if let childStore = store.scope(state: \.childSolo, action: \.childSolo) {
//          ChildView(store: childStore)
//        }

        Color.red.frame(height: 10)

        Text("Child array:")
        ForEach(
          store.scope(state: \.childArray, action: \.childArray)
        ) { childStore in
          ChildView(store: childStore)
        }
      }
    }
  }
}

struct ContentView: View {
  @State var mainStore: StoreOf<MainFeature> = Store(initialState: MainFeature.State()) {
    MainFeature()._printChanges()
  }
  var body: some View {
    MainView(store: mainStore)
  }
}
