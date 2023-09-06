import ComposableArchitecture
import SwiftUI

@main
struct StandupsApp: App {
  var body: some Scene {
    WindowGroup {

      FeatureView()

      // NB: This conditional is here only to facilitate UI testing so that we can mock out certain
      //     dependencies for the duration of the test (e.g. the data manager). We do not really
      //     recommend performing UI tests in general, but we do want to demonstrate how it can be
      //     done.
//      if ProcessInfo.processInfo.environment["UITesting"] == "true" {
//        UITestingView()
//      } else if _XCTIsTesting {
//        // NB: Don't run application when testing so that it doesn't interfere with tests.
//        EmptyView()
//      } else {
//        AppView(
//          store: Store(initialState: AppFeature.State()) {
//            AppFeature()
//              ._printChanges()
//          }
//        )
//      }
    }
  }
}

struct UITestingView: View {
  var body: some View {
    AppView(
      store: Store(initialState: AppFeature.State()) {
        AppFeature()
      } withDependencies: {
        $0.dataManager = .mock()
      }
    )
  }
}


@Observable
class Feature {
  var path: StackState<Int> = StackState() 
}
struct FeatureView: View {
  @State var model = Feature()

  var body: some View {
    NavigationStack(path: self.$model.path) {
      NavigationLink(value: 1) {
        Text("Go")
      }
        .navigationDestination(for: Int.self) { int in
          Text(int.description)
        }
    }
  }
}
