@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct OldContainsNewTestCase: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  struct ViewState: Equatable {
    let childCount: Int
    let count: Int
    let isObservingChildCount: Bool
    init(state: Feature.State) {
      self.childCount = state.child.count
      self.count = state.count
      self.isObservingChildCount = state.isObservingChildCount
    }
  }

  var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      let _ = Logger.shared.log("\(Self.self).body")
      Form {
        Section {
          Text(viewStore.count.description)
          Button("Increment") { self.store.send(.incrementButtonTapped) }
        } header: {
          Text("iOS 16")
        }
        Section {
          if viewStore.isObservingChildCount {
            Text("Child count: \(viewStore.childCount)")
          }
          Button("Toggle observing child count") {
            self.store.send(.toggleIsObservingChildCount)
          }
        }
        Section {
          ObservableBasicsView(store: self.store.scope(state: \.child, action: \.child))
        } header: {
          Text("iOS 17")
        }
      }
    }
  }

  @Reducer
  struct Feature {
    struct State {
      var child = ObservableBasicsView.Feature.State()
      var count = 0
      var isObservingChildCount = false
    }
    enum Action {
      case child(ObservableBasicsView.Feature.Action)
      case incrementButtonTapped
      case toggleIsObservingChildCount
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child, action: \.child) {
        ObservableBasicsView.Feature()
      }
      Reduce { state, action in
        switch action {
        case .child:
          return .none
        case .incrementButtonTapped:
          state.count += 1
          return .none
        case .toggleIsObservingChildCount:
          state.isObservingChildCount.toggle()
          return .none
        }
      }
    }
  }
}

#Preview {
  OldContainsNewTestCase()
}
