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
            "Focus",
            destination: FocusView(
              store: self.store.scope(state: \.focus, action: RootAction.focus)
            )
          )
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
