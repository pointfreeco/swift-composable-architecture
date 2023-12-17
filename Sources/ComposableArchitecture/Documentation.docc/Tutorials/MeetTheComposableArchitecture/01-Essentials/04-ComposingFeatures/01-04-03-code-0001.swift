import SwiftUI

struct AppView: View {
  let store: StoreOf<AppFeature>

  var body: some View {
    TabView {
      CounterView(store: store1)
        .tabItem {
          Text("Counter 1")
        }

      CounterView(store: store2)
        .tabItem {
          Text("Counter 2")
        }
    }
  }
}
