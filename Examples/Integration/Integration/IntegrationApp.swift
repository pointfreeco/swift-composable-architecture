import ComposableArchitecture
import SwiftUI

@main
struct IntegrationApp: App {
  @State var isNavigationStackBindingTestCasePresented = false

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          NavigationLink("EscapedWithViewStoreTestCase") {
            EscapedWithViewStoreTestCaseView(
              store: Store(
                initialState: 10,
                reducer: EscapedWithViewStoreTestCase()
              )
            )
          }
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

          NavigationLink("Binding Animations Test Bench") {
            BindingsAnimationsTestBench(
              store: Store(
                initialState: false,
                reducer: BindingsAnimations()
              )
            )
          }
        }
      }
    }
  }
}
