import ComposableArchitecture
import SwiftUI

struct RootView: View {
  let store: StoreOf<Root>

  var body: some View {
    NavigationView {
      Form {
        Section {
          FocusView(
            store: store.scope(\.focus, action: \.focus)
          )
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    RootView(
      store: Store(initialState: Root.State()) {
        Root()
      }
    )
  }
}
