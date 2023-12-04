import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      //ContentView()
      RootView()
    }
  }
}


import SwiftUI
import ComposableArchitecture

@ObservableState struct MyDocument {
  var number = 0
}

@Reducer struct MyFeature {
  @ObservableState struct State {
    var current = MyDocument()
    var clipboard: MyDocument?
  }

  enum Action {
    case copy
    case increment
    case paste
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .increment:
        state.current.number += 1
      case .copy:
        state.clipboard = state.current
      case .paste:
        if let clipboard = state.clipboard {
          state.current = clipboard
        }
        // state.current.number = state.current.number
        // ^ uncomment to "fix"
      }
      return .none
    }
  }
}

struct ContentView: View {
  @State private var store = Store(initialState: .init()) {
    MyFeature()
  }

  var body: some View {
    VStack {
      Text("Number: \(store.current.number)")

      Button("Increment") {
        store.send(.increment)
      }

      Button("Copy") {
        store.send(.copy)
      }

      Button("Paste") {
        store.send(.paste)
      }
      .disabled(store.clipboard == nil)
    }
  }
}

#Preview {
  ContentView()
}
