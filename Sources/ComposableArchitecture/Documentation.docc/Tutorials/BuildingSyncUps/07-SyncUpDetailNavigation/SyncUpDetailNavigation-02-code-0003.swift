import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {

    } destination: { store in
      
    }
  }
}
