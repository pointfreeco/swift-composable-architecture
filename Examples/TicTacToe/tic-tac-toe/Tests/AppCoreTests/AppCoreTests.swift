import AppCore
import AuthenticationClient
import ComposableArchitecture
import XCTest

class AppCoreTests: XCTestCase {
  func testIntegration() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
      .init(value: .init(token: "deadbeef", twoFactorRequired: false))
    }
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        authenticationClient: authenticationClient,
        mainQueue: .immediate
      )
    )

    store.send(.login(.emailChanged("blob@pointfree.co"))) {
      try (/AppState.login).modify(&$0) {
        $0.email = "blob@pointfree.co"
      }
    }
    store.send(.login(.passwordChanged("bl0bbl0b"))) {
      try (/AppState.login).modify(&$0) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }
    store.send(.login(.loginButtonTapped)) {
      try (/AppState.login).modify(&$0) {
        $0.isLoginRequestInFlight = true
      }
    }
    store.receive(
      .login(.loginResponse(.success(.init(token: "deadbeef", twoFactorRequired: false))))
    ) {
      $0 = .newGame(.init())
    }
    store.send(.newGame(.oPlayerNameChanged("Blob Sr."))) {
      try (/AppState.newGame).modify(&$0) {
        $0.oPlayerName = "Blob Sr."
      }
    }
    store.send(.newGame(.logoutButtonTapped)) {
      $0 = .login(.init())
    }
  }

  func testIntegration_TwoFactor() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
      .init(value: .init(token: "deadbeef", twoFactorRequired: true))
    }
    authenticationClient.twoFactor = { _ in
      .init(value: .init(token: "deadbeef", twoFactorRequired: false))
    }
    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: .init(
        authenticationClient: authenticationClient,
        mainQueue: .immediate
      )
    )

    store.send(.login(.emailChanged("blob@pointfree.co"))) {
      try (/AppState.login).modify(&$0) {
        $0.email = "blob@pointfree.co"
      }
    }

    store.send(.login(.passwordChanged("bl0bbl0b"))) {
      try (/AppState.login).modify(&$0) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }

    store.send(.login(.loginButtonTapped)) {
      try (/AppState.login).modify(&$0) {
        $0.isLoginRequestInFlight = true
      }
    }
    store.receive(
      .login(.loginResponse(.success(.init(token: "deadbeef", twoFactorRequired: true))))
    ) {
      try (/AppState.login).modify(&$0) {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = .init(token: "deadbeef")
      }
    }

    store.send(.login(.twoFactor(.codeChanged("1234")))) {
      try (/AppState.login).modify(&$0) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      }
    }

    store.send(.login(.twoFactor(.submitButtonTapped))) {
      try (/AppState.login).modify(&$0) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      }
    }
    store.receive(
      .login(
        .twoFactor(.twoFactorResponse(.success(.init(token: "deadbeef", twoFactorRequired: false))))
      )
    ) {
      $0 = .newGame(.init())
    }
  }
}
