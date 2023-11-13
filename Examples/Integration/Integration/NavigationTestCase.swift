@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct NavigationTestCaseView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    NavigationStackStore(self.store.scope(state: \.path, action: { .path($0) })) {
      NavigationLink(state: BasicsView.Feature.State()) {
        Text("Push feature")
      }
    } destination: { store in
      Form {
        Section {
          BasicsView(store: store)
        }
        Section {
          NavigationLink(state: BasicsView.Feature.State()) {
            Text("Push feature")
          }
        }
      }
    }
  }

  @Reducer
  struct Feature {
    struct State: Equatable {
      var path = StackState<BasicsView.Feature.State>()
    }
    enum Action {
      case path(StackAction<BasicsView.Feature.State, BasicsView.Feature.Action>)
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        .none
      }
      .forEach(\.path, action: \.path) {
        BasicsView.Feature()
      }
    }
  }
}

struct NavigationPreviews: PreviewProvider {
  static var previews: some View {
    let _ = Logger.shared.isEnabled = true
    NavigationTestCaseView()
  }
}
