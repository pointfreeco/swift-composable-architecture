import AuthenticationClient
import ComposableArchitecture
import LoginCore
import TwoFactorCore
import XCTest

class LoginCoreTests: XCTestCase {
  func testFlow_Success_TwoFactor_Integration() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
    }
    authenticationClient.twoFactor = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
    }

    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: .immediate
      )
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
    store.receive(
      .loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true)))
    ) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = TwoFactorState(token: "deadbeefdeadbeef")
    }
    store.send(.twoFactor(.codeChanged("1234"))) {
      $0.twoFactor?.code = "1234"
      $0.twoFactor?.isFormValid = true
    }
    store.send(.twoFactor(.submitButtonTapped)) {
      $0.twoFactor?.isTwoFactorRequestInFlight = true
    }
    store.receive(
      .twoFactor(
        .twoFactorResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false)))
      )
    ) {
      $0.twoFactor?.isTwoFactorRequestInFlight = false
    }
  }

  func testFlow_DismissEarly_TwoFactor_Integration() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
    }
    authenticationClient.twoFactor = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
    }
    let scheduler = DispatchQueue.test

    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: scheduler.eraseToAnyScheduler()
      )
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
    scheduler.advance()
    store.receive(
      .loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true)))
    ) {
      $0.isLoginRequestInFlight = false
      $0.twoFactor = TwoFactorState(token: "deadbeefdeadbeef")
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
