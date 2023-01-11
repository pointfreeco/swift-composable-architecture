import ComposableArchitecture
import SwiftUI

@main
struct IntegrationApp: App {
  @State var isNavigationStackBindingTestCasePresented = false

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          NavigationLink("ForEachBindingTestCase") {
            ForEachBindingTestCaseView(
              store: Store(
                initialState: ForEachBindingTestCase.State(),
                reducer: ForEachBindingTestCase()
              )
            )
          }

          Button("NavigationStackBindingTestCase") {
            self.isNavigationStackBindingTestCasePresented = true
          }
          .sheet(isPresented: self.$isNavigationStackBindingTestCasePresented) {
            NavigationStackBindingTestCaseView(
              store: Store(
                initialState: NavigationStackBindingTestCase.State(),
                reducer: NavigationStackBindingTestCase()
              )
            )
          }
        }
      }
    }
  }
}
