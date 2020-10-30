import AuthenticationClient
import ComposableArchitecture
import LoginCore
import TicTacToeCommon
import TwoFactorCore
import XCTest

class LoginCoreTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testFlow_Success_TwoFactor_Integration() {
    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: .mock(
          login: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
          },
          twoFactor: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
          }
        ),
        mainQueue: AnyScheduler(self.scheduler)
      )
    )

    store.assert(
      .send(.emailChanged("2fa@pointfree.co")) {
        $0.email = "2fa@pointfree.co"
      },
      .send(.passwordChanged("password")) {
        $0.password = "password"
        $0.isFormValid = true
      },
      .send(.loginButtonTapped) {
        $0.isLoginRequestInFlight = true
      },
      .do { self.scheduler.advance() },
      .receive(.loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true))))
      {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = TwoFactorState(token: "deadbeefdeadbeef")
      },
      .send(.twoFactor(.codeChanged("1234"))) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      },
      .send(.twoFactor(.submitButtonTapped)) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(
        .twoFactor(
          .twoFactorResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false))))
      ) {
        $0.twoFactor?.isTwoFactorRequestInFlight = false
      }
    )
  }

  func testFlow_DismissEarly_TwoFactor_Integration() {
    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: .mock(
          login: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
          },
          twoFactor: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
          }
        ),
        mainQueue: AnyScheduler(self.scheduler)
      )
    )

    store.assert(
      .send(.emailChanged("2fa@pointfree.co")) {
        $0.email = "2fa@pointfree.co"
      },
      .send(.passwordChanged("password")) {
        $0.password = "password"
        $0.isFormValid = true
      },
      .send(.loginButtonTapped) {
        $0.isLoginRequestInFlight = true
      },
      .do { self.scheduler.advance() },
      .receive(.loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true))))
      {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = TwoFactorState(token: "deadbeefdeadbeef")
      },
      .send(.twoFactor(.codeChanged("1234"))) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      },
      .send(.twoFactor(.submitButtonTapped)) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      },
      .send(.twoFactorDismissed) {
        $0.twoFactor = nil
      }
    )
  }
}
