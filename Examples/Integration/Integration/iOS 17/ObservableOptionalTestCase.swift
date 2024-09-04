@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableOptionalView: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
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
      if let store = self.store.scope(state: \.child, action: \.child.presented) {
        Form {
          ObservableBasicsView(store: store)
        }
      }
    }
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State: Equatable {
      @Presents var child: ObservableBasicsView.Feature.State?
      var isObservingCount = false
    }
    enum Action {
      case child(PresentationAction<ObservableBasicsView.Feature.Action>)
      case toggleButtonTapped
      case toggleIsObservingCount
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .child:
          return .none
        case .toggleButtonTapped:
          state.child = state.child == nil ? ObservableBasicsView.Feature.State() : nil
          return .none
        case .toggleIsObservingCount:
          state.isObservingCount.toggle()
          return .none
        }
      }
      .ifLet(\.$child, action: \.child) {
        ObservableBasicsView.Feature()
      }
    }
  }
}
