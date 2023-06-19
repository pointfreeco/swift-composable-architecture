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
  @State var isBindingLocalTestCasePresented = false
  @State var isNavigationStackTestCasePresented = false
  @State var isNavigationStackBindingTestCasePresented = false

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

            case .presentationItem:
              NavigationLink(test.rawValue) {
                PresentationItemTestCaseView()
              }

            case .switchStore:
              NavigationLink(test.rawValue) {
                SwitchStoreTestCaseView()
              }

            case .bindingLocal:
              Button(test.rawValue) {
                self.isBindingLocalTestCasePresented = true
              }
              .foregroundColor(.black)
              .sheet(isPresented: self.$isBindingLocalTestCasePresented) {
                BindingLocalTestCaseView()
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
    .overlay(alignment: .bottom) {
      RuntimeWarnings()
    }
  }
}

struct RuntimeWarnings: View {
  @State var runtimeWarnings: [String] = []

  var body: some View {
    VStack {
      if !self.runtimeWarnings.isEmpty {
        ScrollView {
          ForEach(self.runtimeWarnings, id: \.self) { warning in
            HStack(alignment: .firstTextBaseline) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.purple)
              VStack(alignment: .leading, spacing: 4) {
                Text("Runtime warning")
                  .font(.headline)
                Text(warning)
              }
            }
          }
          .padding(EdgeInsets(top: 16, leading: 10, bottom: 16, trailing: 10))
        }
        .frame(maxHeight: 160)
        .background(Color.white)
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 4)
        .padding()
        .transition(.opacity.animation(.default))
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .runtimeWarning)) { notification in
      if let message = notification.userInfo?["message"] as? String {
        self.runtimeWarnings.append(message)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
