@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct EnumView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  struct ViewState: Equatable {
    enum Tag { case feature1, feature2, none }
    let tag: Tag
    init(state: Feature.State) {
      switch state.destination {
      case .feature1:
        self.tag = .feature1
      case .feature2:
        self.tag = .feature2
      case .none:
        self.tag = .none
      }
    }
  }

  var body: some View {
    Form {
      WithViewStore(self.store, observe: ViewState.init) { viewStore in
        let _ = Logger.shared.log("\(Self.self).body")
        Section {
          switch viewStore.tag {
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
      IfLetStore(self.store.scope(state: \.$destination, action: \.destination)) { store in
        SwitchStore(store) {
          switch $0 {
          case .feature1:
            CaseLet(
              \Feature.Destination.State.feature1, action: Feature.Destination.Action.feature1
            ) { store in
              Section {
                BasicsView(store: store)
              } header: {
                Text("Feature 1")
              }
            }
          case .feature2:
            CaseLet(
              \Feature.Destination.State.feature2, action: Feature.Destination.Action.feature2
            ) { store in
              Section {
                BasicsView(store: store)
              } header: {
                Text("Feature 2")
              }
            }
          }
        }
      }
    }
  }

  @Reducer
  struct Feature {
    struct State: Equatable {
      @PresentationState var destination: Destination.State?
    }
    enum Action {
      case destination(PresentationAction<Destination.Action>)
      case toggle1ButtonTapped
      case toggle2ButtonTapped
    }
    @Reducer
    struct Destination {
      enum State: Equatable {
        case feature1(BasicsView.Feature.State)
        case feature2(BasicsView.Feature.State)
      }
      enum Action {
        case feature1(BasicsView.Feature.Action)
        case feature2(BasicsView.Feature.Action)
      }
      var body: some ReducerOf<Self> {
        Scope(state: \.feature1, action: \.feature1) {
          BasicsView.Feature()
        }
        Scope(state: \.feature2, action: \.feature2) {
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
      .ifLet(\.$destination, action: \.destination) {
        Destination()
      }
    }
  }
}

#Preview {
  Logger.shared.isEnabled = true
  return EnumView()
}
