import AppCore
import AuthenticationClient
import ComposableArchitecture
import XCTest

@MainActor
class AppCoreTests: XCTestCase {
  func testIntegration() async {
    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.authenticationClient.login) { _ in
          .init(token: "deadbeef", twoFactorRequired: false)
        }
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.login(.emailChanged("blob@pointfree.co"))) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.email = "blob@pointfree.co"
      }
    }
    store.send(.login(.passwordChanged("bl0bbl0b"))) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }
    store.send(.login(.loginButtonTapped)) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.isLoginRequestInFlight = true
      }
    }
    await store.receive(
      .login(.loginResponse(.success(.init(token: "deadbeef", twoFactorRequired: false))))
    ) {
      $0 = .newGame(.init())
    }
    store.send(.newGame(.oPlayerNameChanged("Blob Sr."))) {
      try (/AppReducer.State.newGame).modify(&$0) {
        $0.oPlayerName = "Blob Sr."
      }
    }
    store.send(.newGame(.logoutButtonTapped)) {
      $0 = .login(.init())
    }
  }

  func testIntegration_TwoFactor() async {
    let store = TestStore(
      initialState: .init(),
      reducer: AppReducer()
        .dependency(\.authenticationClient.login) { _ in
          .init(token: "deadbeef", twoFactorRequired: true)
        }
        .dependency(\.authenticationClient.twoFactor) { _ in
          .init(token: "deadbeef", twoFactorRequired: false)
        }
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.login(.emailChanged("blob@pointfree.co"))) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.email = "blob@pointfree.co"
      }
    }

    store.send(.login(.passwordChanged("bl0bbl0b"))) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }

    store.send(.login(.loginButtonTapped)) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.isLoginRequestInFlight = true
      }
    }
    await store.receive(
      .login(.loginResponse(.success(.init(token: "deadbeef", twoFactorRequired: true))))
    ) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = .init(token: "deadbeef")
      }
    }

    store.send(.login(.twoFactor(.codeChanged("1234")))) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      }
    }

    store.send(.login(.twoFactor(.submitButtonTapped))) {
      try (/AppReducer.State.login).modify(&$0) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      }
    }
    await store.receive(
      .login(
        .twoFactor(.twoFactorResponse(.success(.init(token: "deadbeef", twoFactorRequired: false))))
      )
    ) {
      $0 = .newGame(.init())
    }
  }
}
