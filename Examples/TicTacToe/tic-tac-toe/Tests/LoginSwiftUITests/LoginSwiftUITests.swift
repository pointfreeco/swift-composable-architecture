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
    let mainQueue = DispatchQueue.test

    let store = Store(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )
    let viewStore = ViewStore(
      store.scope(state: LoginView.ViewState.init, action: LoginAction.init)
    )

    viewStore.send(.emailChanged("blob@pointfree.co"))
    XCTAssertNoDifference(
      .init(
        email: "blob@pointfree.co",
        isActivityIndicatorVisible: false,
        isFormDisabled: false,
        isLoginButtonDisabled: true,
        password: "",
        isTwoFactorActive: false
      ),
      viewStore.state
    )

    viewStore.send(.passwordChanged("password"))
    XCTAssertEqual("password", viewStore.password)
    XCTAssertEqual(false, viewStore.isLoginButtonDisabled)

    viewStore.send(.loginButtonTapped)
    XCTAssertEqual(true, viewStore.isActivityIndicatorVisible)
    XCTAssertEqual(true, viewStore.isFormDisabled)
  }

  func testFlow_TwoFactor() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: true))
    }

    let store = Store(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: .immediate
      )
    )
    let viewStore = ViewStore(
      store.scope(state: LoginView.ViewState.init, action: LoginAction.init)
    )

    viewStore.send(.emailChanged("2fa@pointfree.co"))
    viewStore.send(.passwordChanged("password"))
    viewStore.send(.loginButtonTapped)
    XCTAssertEqual(true, viewStore.isTwoFactorActive)
  }

  func testFlow_Failure() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.login = { _ in Effect(error: .invalidUserPassword) }
    let mainQueue = DispatchQueue.test

    let store = Store(
      initialState: LoginState(),
      reducer: loginReducer,
      environment: LoginEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )
    let viewStore = ViewStore(
      store.scope(state: LoginView.ViewState.init, action: LoginAction.init)
    )

    viewStore.send(.emailChanged("blob"))
    viewStore.send(.passwordChanged("password"))
    viewStore.send(.loginButtonTapped)
    XCTAssertEqual(true, viewStore.isActivityIndicatorVisible)
    XCTAssertEqual(true, viewStore.isFormDisabled)

    mainQueue.advance()
    XCTAssertNoDifference(
      .init(title: TextState(AuthenticationError.invalidUserPassword.localizedDescription)),
      viewStore.alert
    )
    XCTAssertEqual(false, viewStore.isActivityIndicatorVisible)
    XCTAssertEqual(false, viewStore.isFormDisabled)

    viewStore.send(.alertDismissed)
    XCTAssertEqual(nil, viewStore.alert)
  }
}
