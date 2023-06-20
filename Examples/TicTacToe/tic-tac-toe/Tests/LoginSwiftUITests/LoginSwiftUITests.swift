import AuthenticationClient
import ComposableArchitecture
import LoginCore
import XCTest

@testable import LoginSwiftUI

//@MainActor
//final class LoginSwiftUITests: XCTestCase {
//  func testFlow_Success() async {
//    let store = TestStore(initialState: Login.State()) {
//      Login()
//    } observe: {
//      LoginView.ViewState(state: $0)
//    } send: {
//      Login.Action(action: $0)
//    } withDependencies: {
//      $0.authenticationClient.login = { _ in
//        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
//      }
//    }
//
//    await store.send(.emailChanged("blob@pointfree.co")) {
//      $0.email = "blob@pointfree.co"
//    }
//    await store.send(.passwordChanged("password")) {
//      $0.password = "password"
//      $0.isLoginButtonDisabled = false
//    }
//    await store.send(.loginButtonTapped) {
//      $0.isActivityIndicatorVisible = true
//      $0.isFormDisabled = true
//    }
//    await store.receive(
//      .loginResponse(
//        .success(AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false))
//      )
//    ) {
//      $0.isActivityIndicatorVisible = false
//      $0.isFormDisabled = false
//    }
//  }
//
//  func testFlow_Success_TwoFactor() async {
//    let store = TestStore(initialState: Login.State()) {
//      Login()
//    } observe: {
//      LoginView.ViewState(state: $0)
//    } send: {
//      Login.Action(action: $0)
//    } withDependencies: {
//      $0.authenticationClient.login = { _ in
//        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true)
//      }
//    }
//
//    await store.send(.emailChanged("2fa@pointfree.co")) {
//      $0.email = "2fa@pointfree.co"
//    }
//    await store.send(.passwordChanged("password")) {
//      $0.password = "password"
//      $0.isLoginButtonDisabled = false
//    }
//    let twoFactorPresentationTask = await store.send(.loginButtonTapped) {
//      $0.isActivityIndicatorVisible = true
//      $0.isFormDisabled = true
//    }
//    await store.receive(
//      .loginResponse(
//        .success(AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: true))
//      )
//    ) {
//      $0.isActivityIndicatorVisible = false
//      $0.isFormDisabled = false
//    }
//    await twoFactorPresentationTask.cancel()
//  }
//
//  func testFlow_Failure() async {
//    let store = TestStore(initialState: Login.State()) {
//      Login()
//    } observe: {
//      LoginView.ViewState(state: $0)
//    } send: {
//      Login.Action(action: $0)
//    } withDependencies: {
//      $0.authenticationClient.login = { _ in
//        throw AuthenticationError.invalidUserPassword
//      }
//    }
//
//    await store.send(.emailChanged("blob")) {
//      $0.email = "blob"
//    }
//    await store.send(.passwordChanged("password")) {
//      $0.password = "password"
//      $0.isLoginButtonDisabled = false
//    }
//    await store.send(.loginButtonTapped) {
//      $0.isActivityIndicatorVisible = true
//      $0.isFormDisabled = true
//    }
//    await store.receive(.loginResponse(.failure(AuthenticationError.invalidUserPassword))) {
//      $0.alert = AlertState {
//        TextState(AuthenticationError.invalidUserPassword.localizedDescription)
//      }
//      $0.isActivityIndicatorVisible = false
//      $0.isFormDisabled = false
//    }
//  }
//}
