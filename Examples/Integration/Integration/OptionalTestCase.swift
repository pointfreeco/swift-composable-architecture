@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct OptionalView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  struct ViewState: Equatable {
    var childCount: Int?
    var isChildNonNil: Bool
    var isObservingCount: Bool
    init(state: Feature.State) {
      self.childCount = state.child?.count
      self.isChildNonNil = state.child != nil
      self.isObservingCount = state.isObservingCount
    }
  }

  var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      let _ = Logger.shared.log("\(Self.self).body")
      Form {
        Section {
          Button("Toggle") {
            self.store.send(.toggleButtonTapped)
          }
        }
        if viewStore.isChildNonNil {
          Section {
            if viewStore.isObservingCount {
              Button("Stop observing count") { self.store.send(.toggleIsObservingCount) }
              Text("Count: \(viewStore.childCount ?? 0)")
            } else {
              Button("Observe count") { self.store.send(.toggleIsObservingCount) }
            }
          }
        }
      }
    }
    IfLetStore(self.store.scope(state: \.$child, action: { .child($0) })) { store in
      Form {
        BasicsView(store: store)
      }
    }
  }

  @Reducer
  struct Feature {
    struct State: Equatable {
      @PresentationState var child: BasicsView.Feature.State?
      var isObservingCount = false
    }
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
      .ifLet(\.$child, action: \.child) {
        BasicsView.Feature()
      }
    }
  }
}

struct OptionalPreviews: PreviewProvider {
  static var previews: some View {
    let _ = Logger.shared.isEnabled = true
    OptionalView()
  }
}
