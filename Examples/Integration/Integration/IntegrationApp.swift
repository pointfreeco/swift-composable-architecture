import ComposableArchitecture
import SwiftUI
import TestCases

@main
struct IntegrationApp: App {
  @State var isNavigationStackBindingTestCasePresented = false

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          ForEach(TestCase.allCases) { test in
            switch test {
            case .escapedWithViewStore:
              NavigationLink(test.rawValue) {
                EscapedWithViewStoreTestCaseView()
              }

            case .forEachBinding:
              NavigationLink(test.rawValue) {
                ForEachBindingTestCaseView()
              }

            case .navigationStackBinding:
              Button(test.rawValue) {
                self.isNavigationStackBindingTestCasePresented = true
              }
              .foregroundColor(.black)
              .sheet(isPresented: self.$isNavigationStackBindingTestCasePresented) {
                NavigationStackBindingTestCaseView()
              }

            case .presentation:
              NavigationLink(test.rawValue) {
                PresentationTestCaseView()
              }
            }
          }

          NavigationLink("Binding Animations Test Bench") {
            BindingsAnimationsTestBench()
          }
        }
      }
    }
  }
}
