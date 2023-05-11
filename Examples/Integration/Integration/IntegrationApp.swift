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
              store: Store(initialState: 10) {
                EscapedWithViewStoreTestCase()
              }
            )
          }
          NavigationLink("ForEachBindingTestCase") {
            ForEachBindingTestCaseView(
              store: Store(initialState: ForEachBindingTestCase.State()) {
                ForEachBindingTestCase()
              }
            )
          }

          Button("NavigationStackBindingTestCase") {
            self.isNavigationStackBindingTestCasePresented = true
          }
          .sheet(isPresented: self.$isNavigationStackBindingTestCasePresented) {
            NavigationStackBindingTestCaseView(
              store: Store(initialState: NavigationStackBindingTestCase.State()) {
                NavigationStackBindingTestCase()
              }
            )
          }

          NavigationLink("SwitchStoreTestCase") {
            SwitchStoreTestCaseView(
              store: Store(initialState: SwitchStoreTestCase.State.screenA()) {
                SwitchStoreTestCase()
              }
            )
          }

          NavigationLink("Binding Animations Test Bench") {
            BindingsAnimationsTestBench(
              store: Store(initialState: false) {
                BindingsAnimations()
              }
            )
          }
        }
      }
    }
  }
}
