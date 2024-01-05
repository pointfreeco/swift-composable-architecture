@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct NewPresentsOldTestCase: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      Form {
        Section {
          Text(self.store.count.description)
          Button("Increment") {
            self.store.send(.incrementButtonTapped)
          }
        }
        Section {
          if self.store.isObservingChildCount {
            Text("Child count: " + (store.child?.count.description ?? "N/A"))
          }
          Button("Toggle observe child count") {
            self.store.send(.toggleObservingChildCount)
          }
        }
        Section {
          Button("Present child") { self.store.send(.presentChildButtonTapped) }
        }
      }
      .sheet(store: self.store.scope(state: \.$child, action: \.child)) { store in
        Form {
          BasicsView(store: store)
        }
        .presentationDetents([.medium])
      }
    }
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State {
      @Presents var child: BasicsView.Feature.State?
      var count = 0
      var isObservingChildCount = false
    }
    enum Action {
      case child(PresentationAction<BasicsView.Feature.Action>)
      case incrementButtonTapped
      case presentChildButtonTapped
      case toggleObservingChildCount
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child:
          return .none
        case .incrementButtonTapped:
          state.count += 1
          return .none
        case .presentChildButtonTapped:
          state.child = BasicsView.Feature.State()
          return .none
        case .toggleObservingChildCount:
          state.isObservingChildCount.toggle()
          return .none
        }
      }
      .ifLet(\.$child, action: \.child) {
        BasicsView.Feature()
      }
    }
  }
}

#Preview {
  NewPresentsOldTestCase()
}
