@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableEnumScopePresentationView: View {
  @Perception.Bindable var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    WithPerceptionTracking {
      let _ = Logger.shared.log("\(Self.self).body")
      let destination = self.$store.scope(\.destination, action: \.destination)
      Form {
        Button("Present full-screen cover") {
          self.store.send(.presentFullScreenCoverButtonTapped)
        }
      }
      .fullScreenCover(item: destination.fullScreenCover) { store in
        NavigationStack {
          Form {
            Button("Push feature") {
              self.store.send(.pushFeatureButtonTapped)
            }
            ObservableBasicsView(store: store)
          }
          .navigationTitle("Full-screen cover")
        }
      }
      .navigationDestination(item: destination.push) { store in
        Form {
          ObservableBasicsView(store: store)
        }
        .navigationTitle("Pushed feature")
      }
    }
  }

  @Reducer
  struct Feature {
    @Reducer
    enum Destination {
      case fullScreenCover(ObservableBasicsView.Feature)
      case push(ObservableBasicsView.Feature)
    }
    @ObservableState
    struct State: Equatable {
      @Presents var destination: Destination.State?
    }
    enum Action {
      case destination(PresentationAction<Destination.Action>)
      case presentFullScreenCoverButtonTapped
      case pushFeatureButtonTapped
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .destination:
          return .none
        case .presentFullScreenCoverButtonTapped:
          state.destination = .fullScreenCover(ObservableBasicsView.Feature.State())
          return .none
        case .pushFeatureButtonTapped:
          state.destination = .push(ObservableBasicsView.Feature.State())
          return .none
        }
      }
      .ifLet(\.$destination, action: \.destination)
    }
  }
}
extension ObservableEnumScopePresentationView.Feature.Destination.State: Equatable {}
