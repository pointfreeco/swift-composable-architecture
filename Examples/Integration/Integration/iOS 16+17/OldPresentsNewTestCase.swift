@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct OldPresentsNewTestCase: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  struct ViewState: Equatable {
    let childCount: Int?
    let count: Int
    let isObservingChildCount: Bool
    init(state: Feature.State) {
      self.childCount = state.child?.count
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
        }
        Section {
          if viewStore.isObservingChildCount {
            Text("Child count: " + (viewStore.childCount?.description ?? "N/A"))
          }
          Button("Toggle observe child count") {
            self.store.send(.toggleObservingChildCount)
          }
        }
        Section {
          Button("Present child") { self.store.send(.presentChildButtonTapped) }
        }
      }
    }
    .sheet(store: self.store.scope(state: \.$child, action: \.child)) { store in
      Form {
        ObservableBasicsView(store: store)
      }
      .presentationDetents([.medium])
    }
  }

  @Reducer
  struct Feature {
    struct State {
      @PresentationState var child: ObservableBasicsView.Feature.State?
      var count = 0
      var isObservingChildCount = false
    }
    enum Action {
      case child(PresentationAction<ObservableBasicsView.Feature.Action>)
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
          state.child = ObservableBasicsView.Feature.State()
          return .none
        case .toggleObservingChildCount:
          state.isObservingChildCount.toggle()
          return .none
        }
      }
      .ifLet(\.$child, action: \.child) {
        ObservableBasicsView.Feature()
      }
    }
  }
}

#Preview {
  OldPresentsNewTestCase()
}
