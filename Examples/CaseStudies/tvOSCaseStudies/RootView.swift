import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: StoreOf<Root>

  var body: some View {
    NavigationView {
      Form {
        Section {
          self.focusView
        }
      }
    }
  }

  var focusView: AnyView? {
    if #available(tvOS 14.0, *) {
      return AnyView(
        NavigationLink(
          "Focus",
          destination: FocusView(
            store: self.store.scope(state: \.focus, action: Root.Action.focus)
          )
        )
      )
    } else {
      return nil
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
