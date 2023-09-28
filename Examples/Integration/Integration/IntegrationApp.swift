@_spi(Logging) import ComposableArchitecture
import SwiftUI
import TestCases

private struct LogsView: View {
  @State var logs: [String] = []

  var body: some View {
    if ProcessInfo.processInfo.environment["UI_TEST"] != nil {
      VStack {
        Button("Clear logs") { Logger.shared.clear() }
          .accessibilityIdentifier("composable-architecture.debug.clear-logs")

        Spacer()

        Text(self.logs.joined(separator: "\n"))
          .accessibilityIdentifier("composable-architecture.debug.logs")
          .allowsHitTesting(false)
      }
      .background(Color.clear)
      .onReceive(Logger.shared.$logs) { self.logs = $0 }
    }
  }
}

final class IntegrationSceneDelegate: NSObject, UIWindowSceneDelegate {
  var keyWindow: UIWindow!
  var logsWindow: UIWindow!

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene
    else { return }

    self.keyWindow = UIWindow(windowScene: windowScene)
    self.keyWindow.rootViewController = UIHostingController(rootView: ContentView())

    self.logsWindow = UIWindow(windowScene: windowScene)
    self.logsWindow.rootViewController = UIHostingController(rootView: LogsView())
    self.logsWindow.rootViewController?.view.backgroundColor = .clear

    let switchToLogsButton = UIButton()
    switchToLogsButton.setTitle("Switch to logs", for: .normal)
    switchToLogsButton.addAction(UIAction(handler: { _ in
      self.logsWindow.makeKeyAndVisible()
    }), for: .touchUpInside)
    switchToLogsButton.sizeToFit()
    switchToLogsButton.frame.origin.y = 100
    switchToLogsButton.backgroundColor = .red
    self.keyWindow.rootViewController?.view.addSubview(switchToLogsButton)

    let switchToWindowButton = UIButton()
    switchToWindowButton.setTitle("Switch to window", for: .normal)
    switchToWindowButton.addAction(UIAction(handler: { _ in
      self.keyWindow.makeKeyAndVisible()
    }), for: .touchUpInside)
    switchToWindowButton.sizeToFit()
    switchToWindowButton.frame.origin.y = 100
    switchToWindowButton.backgroundColor = .red
    self.logsWindow.rootViewController?.view.addSubview(switchToWindowButton)

    self.keyWindow.makeKeyAndVisible()
  }
}
final class IntegrationAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    sceneConfig.delegateClass = IntegrationSceneDelegate.self
    return sceneConfig
  }
}

@main
struct IntegrationApp: App {
  @UIApplicationDelegateAdaptor var appDelegate: IntegrationAppDelegate
  var body: some Scene {
    WindowGroup {}
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
          NavigationLink("Basics") {
            Form {
              BasicsView()
            }
          }
          NavigationLink("Enum") {
            EnumView()
          }
          NavigationLink("Optional") {
            OptionalView()
          }
          NavigationLink("Identified list") {
            IdentifiedListView()
          }
          NavigationLink("Siblings") {
            SiblingFeaturesView()
          }
          NavigationLink("Presentation") {
            PresentationView()
          }
        }

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
        } header: {
          Text("Legacy")
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
