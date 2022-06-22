import AuthenticationClient
import Combine
import ComposableArchitecture
import TwoFactorCore
import XCTest

@testable import TwoFactorSwiftUI

@MainActor
class TwoFactorSwiftUITests: XCTestCase {
  func testFlow_Success() async {
    let store = TestStore(
      initialState: TwoFactor.State(token: "deadbeefdeadbeef"),
      reducer: TwoFactor(tearDownToken: Never.self)
        .dependency(\.authenticationClient.twoFactor) { _ in
          AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
        }
    )
    .scope(state: TwoFactorView.ViewState.init, action: TwoFactor.Action.init)

    store.send(.codeChanged("1")) {
      $0.code = "1"
    }
    store.send(.codeChanged("12")) {
      $0.code = "12"
    }
    store.send(.codeChanged("123")) {
      $0.code = "123"
    }
    store.send(.codeChanged("1234")) {
      $0.code = "1234"
      $0.isSubmitButtonDisabled = false
    }
    store.send(.submitButtonTapped) {
      $0.isActivityIndicatorVisible = true
      $0.isFormDisabled = true
    }
    await store.receive(
      .twoFactorResponse(
        .success(
          AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
        )
      )
    ) {
      $0.isActivityIndicatorVisible = false
      $0.isFormDisabled = false
    }
  }

  func testFlow_Failure() async {
    let store = TestStore(
      initialState: TwoFactor.State(token: "deadbeefdeadbeef"),
      reducer: TwoFactor(tearDownToken: Never.self)
        .dependency(\.authenticationClient.twoFactor) { _ in
          throw AuthenticationError.invalidTwoFactor
        }
    )
    .scope(state: TwoFactorView.ViewState.init, action: TwoFactor.Action.init)

    store.send(.codeChanged("1234")) {
      $0.code = "1234"
      $0.isSubmitButtonDisabled = false
    }
    store.send(.submitButtonTapped) {
      $0.isActivityIndicatorVisible = true
      $0.isFormDisabled = true
    }
    await store.receive(.twoFactorResponse(.failure(AuthenticationError.invalidTwoFactor))) {
      $0.alert = AlertState(
        title: TextState(AuthenticationError.invalidTwoFactor.localizedDescription)
      )
      $0.isActivityIndicatorVisible = false
      $0.isFormDisabled = false
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
  }
}
