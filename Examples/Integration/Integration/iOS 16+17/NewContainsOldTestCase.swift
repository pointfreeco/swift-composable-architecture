@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct NewContainsOldTestCase: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      Form {
        Section {
          Text(self.store.count.description)
          Button("Increment") { self.store.send(.incrementButtonTapped) }
        } header: {
          Text("iOS 17")
        }
        Section {
          if self.store.isObservingChildCount {
            Text("Child count: \(self.store.child.count)")
          }
          Button("Toggle observe child count") {
            self.store.send(.toggleIsObservingChildCount)
          }
        }
        Section {
          BasicsView(store: self.store.scope(state: \.child, action: \.child))
        } header: {
          Text("iOS 16")
        }
      }
    }
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State {
      var child = BasicsView.Feature.State()
      var count = 0
      var isObservingChildCount = false
    }
    enum Action {
      case child(BasicsView.Feature.Action)
      case incrementButtonTapped
      case toggleIsObservingChildCount
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child, action: \.child) {
        BasicsView.Feature()
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
  NewContainsOldTestCase()
}
