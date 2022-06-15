import AuthenticationClient
import ComposableArchitecture
import LoginCore
import TwoFactorCore
import XCTest

@MainActor
class LoginCoreTests: XCTestCase {
  func testFlow_Success_TwoFactor_Integration() async {
    let store = _TestStore(
      initialState: .init(),
      reducer: Login()
        .dependency(\.authenticationClient.login) { _ in
          .init(token: "deadbeefdeadbeef", twoFactorRequired: true)
        }
        .dependency(\.authenticationClient.twoFactor) { _ in
          .init(token: "deadbeefdeadbeef", twoFactorRequired: false)
        }
        .dependency(\.mainQueue, .immediate)
    )

    store.send(.emailChanged("2fa@pointfree.co")) {
      $0.email = "2fa@pointfree.co"
    }
    store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isFormValid = true
    }
    store.send(.loginButtonTapped) {
      $0.isLoginRequestInFlight = true
    }
    await store.receive(
      .loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true)))
    ) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = .init(token: "deadbeefdeadbeef")
    }
    store.send(.twoFactor(.codeChanged("1234"))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    store.send(.twoFactor(.submitButtonTapped)) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    await store.receive(
      .twoFactor(
        .twoFactorResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false)))
      )
    ) {
      $0.twoFactor?.isTwoFactorRequestInFlight = false
    }
  }

  func testFlow_DismissEarly_TwoFactor_Integration() async {
    let store = _TestStore(
      initialState: .init(),
      reducer: Login()
        .dependency(\.authenticationClient.login) { _ in
          .init(token: "deadbeefdeadbeef", twoFactorRequired: true)
        }
        .dependency(\.authenticationClient.twoFactor) { _ in
          .init(token: "deadbeefdeadbeef", twoFactorRequired: false)
        }
    )

    store.send(.emailChanged("2fa@pointfree.co")) {
      $0.email = "2fa@pointfree.co"
    }
    store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isFormValid = true
    }
    store.send(.loginButtonTapped) {
      $0.isLoginRequestInFlight = true
    }
    await store.receive(
      .loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true)))
    ) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = .init(token: "deadbeefdeadbeef")
    }
    store.send(.twoFactor(.codeChanged("1234"))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    store.send(.twoFactor(.submitButtonTapped)) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    store.send(.twoFactorDismissed) {
      $0.twoFactor = nil
    }
  }
}
