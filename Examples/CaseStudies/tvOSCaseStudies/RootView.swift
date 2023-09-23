import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: StoreOf<Root>

  var body: some View {
    NavigationView {
      Form {
        Section {
          if #available(tvOS 14.0, *) {
            NavigationLink("Focus") {
              FocusView(store: self.store.scope(#feature(\.focus)))
            }
          }
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      RootView(
        store: Store(initialState: Root.State()) {
          Root()
        }
      )
    }
  }
}
