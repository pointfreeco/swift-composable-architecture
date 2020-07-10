import SwiftUI

struct RootView: View {
  var body: some View {
    Form {
      Section {
        Text("Focus")
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      RootView()
    }
  }
}
