import ComposableArchitecture
import SwiftUI

@Reducer
struct AppReducer {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<AppReducer>
}
