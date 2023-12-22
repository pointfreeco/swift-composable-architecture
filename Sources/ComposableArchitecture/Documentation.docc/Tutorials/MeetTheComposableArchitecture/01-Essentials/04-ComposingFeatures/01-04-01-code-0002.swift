import SwiftUI

struct AppView: View {
  var body: some View {
    TabView {
      CounterView(store: ???)
        .tabItem {
          Text("Counter 1")
        }

      CounterView(store: ???)
        .tabItem {
          Text("Counter 2")
        }
    }
  }
}
