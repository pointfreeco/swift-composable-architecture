import ComposableArchitecture
import SwiftUI
import TestCases

@main
struct IntegrationApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

struct ContentView: View {
  @State var isNavigationStackTestCasePresented = false
  @State var isNavigationStackBindingTestCasePresented = false
  @State var runtimeWarnings: [String] = []

  var body: some View {
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

        ForEach(self.runtimeWarnings, id: \.self) { warning in
          VStack(alignment: .leading) {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.purple)
              Text("Runtime warning")
            }
            .font(.largeTitle)
            Text(warning)
          }
        }
      }
    }
    .task {
      for await notification in NotificationCenter.default.notifications(named: .runtimeWarning) {
        if let message = notification.userInfo?["message"] as? String {
          self.runtimeWarnings.append(message)
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
