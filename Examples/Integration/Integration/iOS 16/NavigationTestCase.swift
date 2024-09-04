@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct NavigationTestCaseView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    NavigationStackStore(self.store.scope(state: \.path, action: \.path)) {
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
      case path(StackActionOf<BasicsView.Feature>)
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

#Preview {
  Logger.shared.isEnabled = true
  return NavigationTestCaseView()
}
