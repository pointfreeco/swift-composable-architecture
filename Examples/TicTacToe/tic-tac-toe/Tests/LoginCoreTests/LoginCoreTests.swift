import AuthenticationClient
import ComposableArchitecture
import LoginCore
import TwoFactorCore
import XCTest

@MainActor
final class LoginCoreTests: XCTestCase {
  func testFlow_Success_TwoFactor_Integration() async {
    let store = TestStore(initialState: Login.State()) {
      Login()
    } withDependencies: {
      $0.authenticationClient.login = { _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true)
      }
      $0.authenticationClient.twoFactor = { _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
      }
    }

    await store.send(.view(.set(\.$email, "2fa@pointfree.co"))) {
      $0.email = "2fa@pointfree.co"
    }
    await store.send(.view(.set(\.$password, "password"))) {
      $0.password = "password"
      $0.isFormValid = true
    }
    let twoFactorPresentationTask = await store.send(.view(.loginButtonTapped)) {
      $0.isLoginRequestInFlight = true
    }
    await store.receive(\.loginResponse.success) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = TwoFactor.State(token: "deadbeefdeadbeef")
    }
    await store.send(.twoFactor(.presented(.view(.set(\.$code, "1234"))))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    await store.send(.twoFactor(.presented(.view(.submitButtonTapped)))) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    await store.receive(\.twoFactor.twoFactorResponse.success) {
      $0.twoFactor?.isTwoFactorRequestInFlight = false
    }
    await twoFactorPresentationTask.cancel()
  }

  func testFlow_DismissEarly_TwoFactor_Integration() async {
    let store = TestStore(initialState: Login.State()) {
      Login()
    } withDependencies: {
      $0.authenticationClient.login = { _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true)
      }
      $0.authenticationClient.twoFactor = { _ in
        try await Task.sleep(for: .seconds(1))
        return AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
      }
    }

    await store.send(.view(.set(\.$email, "2fa@pointfree.co"))) {
      $0.email = "2fa@pointfree.co"
    }
    await store.send(.view(.set(\.$password, "password"))) {
      $0.password = "password"
      $0.isFormValid = true
    }
    await store.send(.view(.loginButtonTapped)) {
      $0.isLoginRequestInFlight = true
    }
    await store.receive(\.loginResponse.success) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = TwoFactor.State(token: "deadbeefdeadbeef")
    }
    await store.send(.twoFactor(.presented(.view(.set(\.$code, "1234"))))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    await store.send(.twoFactor(.presented(.view(.submitButtonTapped)))) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    await store.send(.twoFactor(.dismiss)) {
      $0.twoFactor = nil
    }
    await store.finish()
  }
}
