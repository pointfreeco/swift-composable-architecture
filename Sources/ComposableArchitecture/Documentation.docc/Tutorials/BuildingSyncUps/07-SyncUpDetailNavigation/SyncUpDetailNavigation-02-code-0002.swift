import ComposableArchitecture
import SwiftUI

@Reducer
struct App {
  // ...
}

struct AppView: View {
  @Bindable var store: StoreOf<App>
}
