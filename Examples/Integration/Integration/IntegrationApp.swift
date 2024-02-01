@_spi(Logging) import ComposableArchitecture
import SwiftUI
import TestCases

private struct LogsView: View {
  @State var logs: [String] = []

  var body: some View {
    if ProcessInfo.processInfo.environment["UI_TEST"] != nil {
      VStack {
        Text(self.logs.joined(separator: "\n"))
          .accessibilityIdentifier("composable-architecture.debug.logs")
          .allowsHitTesting(false)
      }
      .background(Color.clear)
      .onReceive(Logger.shared.$logs) { self.logs = $0 }
      .onReceive(NotificationCenter.default.publisher(for: .clearLogs)) { _ in
        Logger.shared.clear()
      }
    }
  }
}

final class IntegrationSceneDelegate: NSObject, UIWindowSceneDelegate {
  var keyWindow: UIWindow!
  var logsWindow: UIWindow!

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    NotificationCenter.default.post(name: .clearLogs, object: nil)
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene
    else { return }

    self.logsWindow = UIWindow(windowScene: windowScene)
    self.logsWindow.rootViewController = UIHostingController(rootView: LogsView())
    self.logsWindow.rootViewController?.view.backgroundColor = .clear
    self.logsWindow.isUserInteractionEnabled = false
    self.logsWindow.makeKeyAndVisible()

    self.keyWindow = UIWindow(windowScene: windowScene)
    self.keyWindow.rootViewController = UIHostingController(rootView: ContentView())
    self.keyWindow.makeKeyAndVisible()
  }
}
final class IntegrationAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    Logger.shared.isEnabled = true
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
  @State var isNavigationTestCasePresented = false
  @State var isObservableBindingLocalTestCasePresented = false
  @State var isObservableNavigationTestCasePresented = false

  var body: some View {
    NavigationStack {
      List {
        NavigationLink("iOS 17") {
          List {
            Section {
              NavigationLink("Basics") {
                Form {
                  ObservableBasicsView(showExtraButtons: true)
                }
              }
              Button("Binding local") {
                self.isObservableBindingLocalTestCasePresented.toggle()
              }
              .sheet(isPresented: self.$isObservableBindingLocalTestCasePresented) {
                ObservableBindingLocalTestCaseView()
              }
              NavigationLink("Enum") {
                ObservableEnumView()
              }
              NavigationLink("Optional") {
                ObservableOptionalView()
              }
              NavigationLink("Identified list") {
                ObservableIdentifiedListView()
              }
              Button("Navigation") {
                self.isObservableNavigationTestCasePresented = true
              }
              .sheet(isPresented: self.$isObservableNavigationTestCasePresented) {
                ObservableNavigationTestCaseView()
              }
              NavigationLink("Shared state") {
                ObservableSharedStateView()
              }
              NavigationLink("Siblings") {
                ObservableSiblingFeaturesView()
              }
              NavigationLink("Presentation") {
                ObservablePresentationView()
              }
            }
          }
          .navigationTitle("iOS 17")
        }

        NavigationLink("iOS 16 + 17") {
          List {
            NavigationLink("New containing old") {
              NewContainsOldTestCase()
            }
            NavigationLink("Siblings") {
              NewOldSiblingsView()
            }
            NavigationLink("New presents old") {
              NewPresentsOldTestCase()
            }
            NavigationLink("Old containing new") {
              OldContainsNewTestCase()
            }
            NavigationLink("Old presents new") {
              OldPresentsNewTestCase()
            }
          }
          .navigationTitle(Text("iOS 16 + 17"))
        }

        NavigationLink("iOS 16") {
          List {
            Section {
              NavigationLink("Basics") {
                Form {
                  BasicsView(
                    store: Store(initialState: BasicsView.Feature.State()) {
                      BasicsView.Feature()
                    }
                  )
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
              Button("Navigation") {
                self.isNavigationTestCasePresented = true
              }
              .sheet(isPresented: self.$isNavigationTestCasePresented) {
                NavigationTestCaseView()
              }
              NavigationLink("Siblings") {
                SiblingFeaturesView()
              }
              NavigationLink("Presentation") {
                PresentationView()
              }
            }
          }
          .navigationTitle(Text("iOS 16"))
        }

        NavigationLink("Legacy") {
          List {
            ForEach(TestCase.allCases) { test in
              switch test {
              case .escapedWithViewStore:
                NavigationLink(test.rawValue) {
                  EscapedWithViewStoreTestCaseView()
                }

              case .ifLetStore:
                NavigationLink(test.rawValue) {
                  IfLetStoreTestCase()
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
          .navigationTitle(Text("Legacy"))
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
    .onReceive(NotificationCenter.default.publisher(for: ._runtimeWarning)) { notification in
      if let message = notification.userInfo?["message"] as? String {
        self.runtimeWarnings.append(message)
      }
    }
  }
}

extension Notification.Name {
  static let clearLogs = Self("clear-logs")
}

#Preview {
  ContentView()
}
