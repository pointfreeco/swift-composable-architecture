import ComposableArchitecture
import SwiftUI

private let readMe = """
  This file demonstrates how to open external URLs using state and a SwiftUI view modifier.

  SwiftUI and UIKit provide some simple tools for opening external URLs, such as the `Link`
  view and `UIApplication.shared.OpeningURL` and sometimes that is all you need for simple static
  links within your app.

  Sometimes however, you might need to trigger the opening of a URL as the result of some
  explicit action sent to the store, such as an action on an `AlertState` button or received
  from some `Effect`.

  The library comes with a utility to embed the functionality of opening URLs directly within
  your feature domain with minimal setup and allows you to trigger the opening of a URL with
  a simple state mutation, which also makes it really easy to test.
  """

// The state for this screen holds a bunch of values that will drive
struct OpeningURLBasicsState: Equatable {
  var urlToOpen: URL?
  var errorAlert: AlertState<OpeningURLBasicsAction>?
}

enum OpeningURLBasicsAction: Equatable {
  case tappedToOpen(URL?)
  case openAfterDelay(URL?, TimeInterval)
  case dismissErrorAlert
  case openURL(OpenURLViewAction)
}

struct OpeningURLBasicsEnvironment {
  let mainQueue: AnySchedulerOf<DispatchQueue>
}

let openingURLBasicsReducer = Reducer<
  OpeningURLBasicsState, OpeningURLBasicsAction, OpeningURLBasicsEnvironment
> {
  state, action, environment in
  switch action {
  case let .tappedToOpen(url):
    state.urlToOpen = url
    return .none
  case let .openAfterDelay(url, delay):
    return Effect(value: url)
      .delay(for: .seconds(delay), scheduler: environment.mainQueue)
      .eraseToEffect()
      .map(OpeningURLBasicsAction.tappedToOpen)
  case .openURL(.openedURL(false)):
    state.errorAlert = .init(
      title: .init("URL Error"),
      message: .init("The URL failed to open."),
      dismissButton: .cancel()
    )
    return .none
  case .openURL(.urlNotSupported):
    state.errorAlert = .init(
      title: .init("URL Error"),
      message: .init("The URL is not supported and cannot be opened."),
      dismissButton: .cancel()
    )
    return .none
  case .dismissErrorAlert:
    state.errorAlert = nil
    return .none
  case .openURL:
    return .none
  }
}
.opensURL(
  state: \.urlToOpen,
  action: /OpeningURLBasicsAction.openURL
)

struct OpeningURLBasicsView: View {
  let store: Store<OpeningURLBasicsState, OpeningURLBasicsAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(spacing: 20) {
        Button("Open Pointfree.co") {
          viewStore.send(.tappedToOpen(URL(string: "https://pointfree.co")))
        }
        Button("Open TCA Github Repo") {
          viewStore.send(.tappedToOpen(URL(string: "https://github.com/pointfreeco/swift-composable-architecture")))
        }
        Button("Open URL with delayed effect") {
          viewStore.send(.openAfterDelay(URL(string: "http://example.com"), 2))
        }
        Button("Open unsupported URL") {
          viewStore.send(.tappedToOpen(URL(string: "gopher://localhost:10000")))
        }
      }
    }
    .navigationBarTitle("Opening URLs")
    .alert(
      store.scope(state: \.errorAlert),
      dismiss: .dismissErrorAlert
    )
    .opensURL(
      store.scope(
        state: \.urlToOpen,
        action: OpeningURLBasicsAction.openURL
      )
    )
  }
}

struct OpeningURLBasicsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      OpeningURLBasicsView(
        store: Store(
          initialState: OpeningURLBasicsState(),
          reducer: openingURLBasicsReducer,
          environment: OpeningURLBasicsEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
  }
}
