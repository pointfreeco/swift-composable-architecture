import AuthenticationClient
import Combine
import ComposableArchitecture
import LoginCore
import TicTacToeCommon
import XCTest

@testable import LoginSwiftUI

class LoginSwiftUITests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testFlow_Success() {
    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: .mock(
          login: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
          }
        ),
        mainQueue: .init(self.scheduler)
      )
    )
    .scope(state: { $0.view }, action: LoginAction.view)

    store.assert(
      .send(.emailChanged("blob@pointfree.co")) {
        $0.email = "blob@pointfree.co"
      },
      .send(.passwordChanged("password")) {
        $0.password = "password"
        $0.isLoginButtonDisabled = false
      },
      .send(.loginButtonTapped) {
        $0.isActivityIndicatorVisible = true
        $0.isFormDisabled = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(.loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false))))
      {
        $0.isActivityIndicatorVisible = false
        $0.isFormDisabled = false
      }
    )
  }

  func testFlow_Success_TwoFactor() {
    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: .mock(
          login: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
          }
        ),
        mainQueue: .init(self.scheduler)
      )
    )
    .scope(state: { $0.view }, action: LoginAction.view)

    store.assert(
      .send(.emailChanged("2fa@pointfree.co")) {
        $0.email = "2fa@pointfree.co"
      },
      .send(.passwordChanged("password")) {
        $0.password = "password"
        $0.isLoginButtonDisabled = false
      },
      .send(.loginButtonTapped) {
        $0.isActivityIndicatorVisible = true
        $0.isFormDisabled = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(.loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true))))
      {
        $0.isActivityIndicatorVisible = false
        $0.isFormDisabled = false
        $0.isTwoFactorActive = true
      },
      .send(.twoFactorDismissed) {
        $0.isTwoFactorActive = false
      }
    )
  }

  func testFlow_Failure() {
    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: .mock(
          login: { _ in Effect(error: .invalidUserPassword) }
        ),
        mainQueue: .init(self.scheduler)
      )
    )
    .scope(state: { $0.view }, action: LoginAction.view)

    store.assert(
      .send(.emailChanged("blob")) {
        $0.email = "blob"
      },
      .send(.passwordChanged("password")) {
        $0.password = "password"
        $0.isLoginButtonDisabled = false
      },
      .send(.loginButtonTapped) {
        $0.isActivityIndicatorVisible = true
        $0.isFormDisabled = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(.loginResponse(.failure(.invalidUserPassword))) {
        $0.alert = .init(title: .init(AuthenticationError.invalidUserPassword.localizedDescription))
        $0.isActivityIndicatorVisible = false
        $0.isFormDisabled = false
      },
      .send(.alertDismissed) {
        $0.alert = nil
      }
    )
  }
}
