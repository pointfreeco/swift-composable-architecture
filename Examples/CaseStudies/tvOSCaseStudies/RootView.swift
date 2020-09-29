import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: Store<RootState, RootAction>

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
      #if swift(>=5.3)
        return AnyView(
          NavigationLink(
            destination: FocusView(
              store: self.store.scope(state: { $0.focus }, action: RootAction.focus)
            ),
            label: {
              Text("Focus")
            })
        )
      #else
        return nil
      #endif
    } else {
      return nil
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      RootView(
        store: Store(
          initialState: .init(),
          reducer: rootReducer,
          environment: .init()
        )
      )
    }
  }
}
