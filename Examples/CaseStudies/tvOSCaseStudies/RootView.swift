import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: Store<RootState, RootAction>
  
  var body: some View {
    NavigationView {
      Form {
        Section {
          NavigationLink(
            destination: FocusView(
              store: self.store.scope(state: \.focus, action: RootAction.focus)
            ),
            label: {
              Text("Focus")
            }
          )
        }
      }
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
