import ComposableArchitecture
import SwiftUI

struct EnumView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    let _ = Log.shared.log("\(Self.self).body")
    Form {
      Section {
        switch self.store.destination {
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
    }
    if let destinationStore = self.store.scope(state: \.destination, action: { .destination($0) }) {
      switch destinationStore.state {
      case .feature1:
        Section {
          if let childStore = destinationStore.scope(state: \.feature1, action: { .feature1($0) }) {
            BasicsView(store: childStore)
          }
        } header: {
          Text("Feature 1")
        }
      case .feature2:
        Section {
          if let childStore = destinationStore.scope(state: \.feature2, action: { .feature2($0) }) {
            BasicsView(store: childStore)
          }
        } header: {
          Text("Feature 2")
        }
      }
    }
  }

  struct Feature: Reducer {
    @ObservableState
    struct State {
      @ObservationStateIgnored
      @PresentationState var destination: Destination.State?
    }
    @CasePathable
    enum Action {
      case destination(PresentationAction<Destination.Action>)
      case toggle1ButtonTapped
      case toggle2ButtonTapped
    }
    struct Destination: Reducer {
      @CasePathable
      @ObservableState
      enum State {
        case feature1(BasicsView.Feature.State)
        case feature2(BasicsView.Feature.State)
      }
      @CasePathable
      enum Action {
        case feature1(BasicsView.Feature.Action)
        case feature2(BasicsView.Feature.Action)
      }
      var body: some ReducerOf<Self> {
        Scope(state: #casePath(\.feature1), action: #casePath(\.feature1)) {
          BasicsView.Feature()
        }
        Scope(state: #casePath(\.feature2), action: #casePath(\.feature2)) {
          BasicsView.Feature()
        }
      }
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
            state.destination = .feature1(BasicsView.Feature.State())
          case .none:
            state.destination = .feature1(BasicsView.Feature.State())
          }
          return .none
        case .toggle2ButtonTapped:
          switch state.destination {
          case .feature1:
            state.destination = .feature2(BasicsView.Feature.State())
          case .feature2:
            state.destination = nil
          case .none:
            state.destination = .feature2(BasicsView.Feature.State())
          }
          return .none
        }
      }
      .ifLet(\.$destination, action: #casePath(\.destination)) {
        Destination()
      }
    }
  }
}
