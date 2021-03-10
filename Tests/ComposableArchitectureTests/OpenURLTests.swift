import XCTest

@testable import ComposableArchitecture

class OpenURLTests: XCTestCase {
  struct AppState: Equatable {
    var url: URL?
  }

  enum AppAction: Equatable {
    case tappedToOpen
    case openURL(OpenURLViewAction)
  }

  let store = TestStore(
    initialState: AppState(),
    reducer: Reducer<AppState, AppAction, Void> { state, action, _ in
      switch action {
      case .tappedToOpen:
        state.url = URL(string: "http://example.com")
        return .none
      case .openURL:
        return .none
      }
    }.opensURL(
      state: \.url,
      action: /AppAction.openURL
    ),
    environment: ()
  )

  func testOpeningSupportedURL() {
    store.assert(
      .send(.tappedToOpen) {
        $0.url = URL(string: "http://example.com")
      },
      .send(.openURL(.openedURL(true))) {
        $0.url = nil
      }
    )
  }

  func testOpeningUnsupportedURL() {
    store.assert(
      .send(.tappedToOpen) {
        $0.url = URL(string: "http://example.com")
      },
      .send(.openURL(.urlNotSupported)) {
        $0.url = nil
      }
    )
  }

  func testOpeningURLFails() {
    store.assert(
      .send(.tappedToOpen) {
        $0.url = URL(string: "http://example.com")
      },
      .send(.openURL(.openedURL(true))) {
        $0.url = nil
      }
    )
  }
}
