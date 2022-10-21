import AuthenticationClient
import ComposableArchitecture
import TwoFactorCore
import XCTest

@testable import TwoFactorSwiftUI

@MainActor
final class TwoFactorSwiftUITests: XCTestCase {
  func testFlow_Success() async {
    let store = TestStore(
      initialState: TwoFactor.State(token: "deadbeefdeadbeef"),
      reducer: TwoFactor()
    )
    .scope(state: TwoFactorView.ViewState.init, action: TwoFactor.Action.init)

    store.dependencies.authenticationClient.twoFactor = { _ in
      AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
    }

    await store.send(.codeChanged("1")) {
      $0.code = "1"
    }
    await store.send(.codeChanged("12")) {
      $0.code = "12"
    }
    await store.send(.codeChanged("123")) {
      $0.code = "123"
    }
    await store.send(.codeChanged("1234")) {
      $0.code = "1234"
      $0.isSubmitButtonDisabled = false
    }
    await store.send(.submitButtonTapped) {
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
      reducer: TwoFactor()
    )
    .scope(state: TwoFactorView.ViewState.init, action: TwoFactor.Action.init)

    store.dependencies.authenticationClient.twoFactor = { _ in
      throw AuthenticationError.invalidTwoFactor
    }

    await store.send(.codeChanged("1234")) {
      $0.code = "1234"
      $0.isSubmitButtonDisabled = false
    }
    await store.send(.submitButtonTapped) {
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
    await store.send(.alertDismissed) {
      $0.alert = nil
    }

    await store.finish()
  }
}
