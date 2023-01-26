import AuthenticationClient
import ComposableArchitecture
import LoginCore
import TwoFactorCore
import XCTest

@MainActor
final class LoginCoreTests: XCTestCase {
  func testFlow_Success_TwoFactor_Integration() async {
    let store = TestStore(
      initialState: Login.State(),
      reducer: Login()
    ) {
      $0.authenticationClient.login = { _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true)
      }
      $0.authenticationClient.twoFactor = { _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
      }
    }

    await store.send(.emailChanged("2fa@pointfree.co")) {
      $0.email = "2fa@pointfree.co"
    }
    await store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isFormValid = true
    }
    await store.send(.loginButtonTapped) {
      $0.isLoginRequestInFlight = true
    }
    await store.receive(
      .loginResponse(
        .success(AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true))
      )
    ) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = TwoFactor.State(token: "deadbeefdeadbeef")
    }
    await store.send(.twoFactor(.codeChanged("1234"))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    await store.send(.twoFactor(.submitButtonTapped)) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    await store.receive(
      .twoFactor(
        .twoFactorResponse(
          .success(AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false))
        )
      )
    ) {
      $0.twoFactor?.isTwoFactorRequestInFlight = false
    }
  }

  func testFlow_DismissEarly_TwoFactor_Integration() async {
    let store = TestStore(
      initialState: Login.State(),
      reducer: Login()
    ) {
      $0.authenticationClient.login = { _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true)
      }
      $0.authenticationClient.twoFactor = { _ in
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
      }
    }

    await store.send(.emailChanged("2fa@pointfree.co")) {
      $0.email = "2fa@pointfree.co"
    }
    await store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isFormValid = true
    }
    await store.send(.loginButtonTapped) {
      $0.isLoginRequestInFlight = true
    }
    await store.receive(
      .loginResponse(
        .success(AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true))
      )
    ) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = TwoFactor.State(token: "deadbeefdeadbeef")
    }
    await store.send(.twoFactor(.codeChanged("1234"))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    await store.send(.twoFactor(.submitButtonTapped)) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    await store.send(.twoFactorDismissed) {
      $0.twoFactor = nil
    }
    await store.finish()
  }
}
