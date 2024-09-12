@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableEnumView: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      Form {
        Section {
          switch store.destination {
          case .feature1:
            Button("Toggle feature 1 off") {
              self.store.send(.toggle1ButtonTapped)
            }
            Button("Toggle feature 2 on") {
              self.store.send(.toggle2ButtonTapped)
            }
          case .feature2:
            Button("Toggle feature 1 on") {
              self.store.send(.toggle1ButtonTapped)
            }
            Button("Toggle feature 2 off") {
              self.store.send(.toggle2ButtonTapped)
            }
          case .none:
            Button("Toggle feature 1 on") {
              self.store.send(.toggle1ButtonTapped)
            }
            Button("Toggle feature 2 on") {
              self.store.send(.toggle2ButtonTapped)
            }
          }
        }
        if let store = self.store.scope(state: \.destination, action: \.destination.presented) {
          switch store.state {
          case .feature1:
            if let store = store.scope(state: \.feature1, action: \.feature1) {
              Section {
                ObservableBasicsView(store: store)
              } header: {
                Text("Feature 1")
              }
            }
          case .feature2:
            if let store = store.scope(state: \.feature2, action: \.feature2) {
              Section {
                ObservableBasicsView(store: store)
              } header: {
                Text("Feature 2")
              }
            }
          }
        }
      }
      // NB: Conditional child views of `Form` that use `@State` are stale when they reappear.
      //     This `id` forces a refresh.
      //
      // Feedback filed: https://gist.github.com/stephencelis/fd078ca2d260c316b70dfc1e0f29883f
      .id(UUID())
    }
  }

  @Reducer
  struct Feature {
    @Reducer
    enum Destination {
      case feature1(ObservableBasicsView.Feature)
      case feature2(ObservableBasicsView.Feature)
    }
    @ObservableState
    struct State: Equatable {
      @Presents var destination: Destination.State?
    }
    enum Action {
      case destination(PresentationAction<Destination.Action>)
      case toggle1ButtonTapped
      case toggle2ButtonTapped
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .destination:
          return .none
        case .toggle1ButtonTapped:
          switch state.destination {
          case .feature1:
            state.destination = nil
          case .feature2:
            state.destination = .feature1(ObservableBasicsView.Feature.State())
          case .none:
            state.destination = .feature1(ObservableBasicsView.Feature.State())
          }
          return .none
        case .toggle2ButtonTapped:
          switch state.destination {
          case .feature1:
            state.destination = .feature2(ObservableBasicsView.Feature.State())
          case .feature2:
            state.destination = nil
          case .none:
            state.destination = .feature2(ObservableBasicsView.Feature.State())
          }
          return .none
        }
      }
      .ifLet(\.$destination, action: \.destination)
    }
  }
}
extension ObservableEnumView.Feature.Destination.State: Equatable {}

#Preview {
  Logger.shared.isEnabled = true
  return ObservableEnumView()
}
