import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>
}
