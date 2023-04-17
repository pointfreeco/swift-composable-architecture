import ComposableArchitecture
import SwiftUI
import TestCases

@main
struct IntegrationApp: App {
  @State var isNavigationStackTestCasePresented = false
  @State var isNavigationStackBindingTestCasePresented = false

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          Section {
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

              case .navigationStack:
                Button(test.rawValue) {
                  self.isNavigationStackTestCasePresented = true
                }
                .foregroundColor(.black)
                .sheet(isPresented: self.$isNavigationStackTestCasePresented) {
                  NavigationStackTestCaseView()
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

              case .switchStore:
                NavigationLink(test.rawValue) {
                  SwitchStoreTestCaseView()
                }
              }
            }
          }

          Section {
            NavigationLink("Binding Animations Test Bench") {
              BindingsAnimationsTestBench()
            }
          }
        }
      }
    }
  }
}
