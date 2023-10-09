import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: StoreOf<Root>

  var body: some View {
    NavigationView {
      Form {
        Section {
          if #available(tvOS 14, *) {
            FocusView(
              store: self.store.scope(state: \.focus, action: { .focus($0) })
            )
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
