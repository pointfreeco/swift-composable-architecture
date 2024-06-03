import ComposableArchitecture
import SwiftUI

@Reducer
struct AppReducer {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<AppReducer>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {

    } destination: { store in
      
    }
  }
}
