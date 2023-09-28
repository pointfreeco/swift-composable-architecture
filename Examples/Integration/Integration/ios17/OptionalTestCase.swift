import ComposableArchitecture
import SwiftUI

struct OptionalView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    let _ = Log.shared.log("\(Self.self).body")
    Form {
      Section {
        Button("Toggle") {
          self.store.send(.toggleButtonTapped)
        }
      }
      if self.store.child != nil {
        Section {
          if self.store.isObservingCount {
            Button("Stop observing count") { self.store.send(.toggleIsObservingCount) }
            Text("Count: \(self.store.child?.count ?? 0)")
          } else {
            Button("Observe count") { self.store.send(.toggleIsObservingCount) }
          }
        }
      }
    }
    if let childStore = self.store.scope(state: \.child, action: { .child($0) }) {
      BasicsView(store: childStore)
    }
  }

  struct Feature: Reducer {
    @ObservableState
    struct State {
      @ObservationStateIgnored
      @PresentationState var child: BasicsView.Feature.State?
      var isObservingCount = false
    }
    @CasePathable
    enum Action {
      case child(PresentationAction<BasicsView.Feature.Action>)
      case toggleButtonTapped
      case toggleIsObservingCount
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child:
          return .none
        case .toggleButtonTapped:
          state.child = state.child == nil ? BasicsView.Feature.State() : nil
          return .none
        case .toggleIsObservingCount:
          state.isObservingCount.toggle()
          return .none
        }
      }
      .ifLet(\.$child, action: #casePath(\.child)) {
        BasicsView.Feature()
      }
    }
  }
}
