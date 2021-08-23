import AuthenticationClient
import Combine
import ComposableArchitecture
import LoginCore
import XCTest

@testable import LoginSwiftUI

class LoginSwiftUITests: XCTestCase {
  func testFlow_Success() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
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
    .scope(state: LoginView.ViewState.init, action: LoginAction.init)

    store.send(.emailChanged("blob@pointfree.co")) {
      $0.email = "blob@pointfree.co"
    }
    store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isLoginButtonDisabled = false
    }
    store.send(.loginButtonTapped) {
      $0.isActivityIndicatorVisible = true
      $0.isFormDisabled = true
    }
    store.receive(
      .loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false)))
    ) {
      $0.isActivityIndicatorVisible = false
      $0.isFormDisabled = false
    }
  }

  func testFlow_Success_TwoFactor() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
    }

    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: .immediate
      )
    )
    .scope(state: LoginView.ViewState.init, action: LoginAction.init)

    store.send(.emailChanged("2fa@pointfree.co")) {
      $0.email = "2fa@pointfree.co"
    }
    store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isLoginButtonDisabled = false
    }
    store.send(.loginButtonTapped) {
      $0.isActivityIndicatorVisible = true
      $0.isFormDisabled = true
    }
    store.receive(
      .loginResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: true)))
    ) {
      $0.isActivityIndicatorVisible = false
      $0.isFormDisabled = false
      $0.isTwoFactorActive = true
    }
    store.send(.twoFactorDismissed) {
      $0.isTwoFactorActive = false
    }
  }

  func testFlow_Failure() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in Effect(error: .invalidUserPassword) }

    let store = TestStore(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: .immediate
      )
    )
    .scope(state: LoginView.ViewState.init, action: LoginAction.init)

    store.send(.emailChanged("blob")) {
      $0.email = "blob"
    }
    store.send(.passwordChanged("password")) {
      $0.password = "password"
      $0.isLoginButtonDisabled = false
    }
    store.send(.loginButtonTapped) {
      $0.isActivityIndicatorVisible = true
      $0.isFormDisabled = true
    }
    store.receive(.loginResponse(.failure(.invalidUserPassword))) {
      $0.alert = .init(
        title: TextState(AuthenticationError.invalidUserPassword.localizedDescription)
      )
      $0.isActivityIndicatorVisible = false
      $0.isFormDisabled = false
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
  }
}
