import AuthenticationClient
import Combine
import ComposableArchitecture
import TicTacToeCommon
import TwoFactorCore
import XCTest

@testable import TwoFactorSwiftUI

class TwoFactorSwiftUITests: XCTestCase {
  func testFlow_Success() {
    let store = TestStore(
      initialState: TwoFactorState(token: "deadbeefdeadbeef"),
      reducer: twoFactorReducer,
      environment: TwoFactorEnvironment(
        authenticationClient: .mock(
          twoFactor: { _ in
            Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
          }
        ),
        mainQueue: .immediate
      )
    )
    .scope(state: TwoFactorView.ViewState.init, action: TwoFactorAction.init)

    store.environment.authenticationClient.twoFactor = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
    }
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
    store.receive(
      .twoFactorResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false)))
    ) {
      $0.isActivityIndicatorVisible = false
      $0.isFormDisabled = false
    }
  }

  func testFlow_Failure() {
    let store = TestStore(
      initialState: TwoFactorState(token: "deadbeefdeadbeef"),
      reducer: twoFactorReducer,
      environment: TwoFactorEnvironment(
        authenticationClient: .mock(
          twoFactor: { _ in
            Effect(error: .invalidTwoFactor)
          }
        ),
        mainQueue: .immediate
      )
    )
    .scope(state: TwoFactorView.ViewState.init, action: TwoFactorAction.init)

    store.send(.codeChanged("1234")) {
      $0.code = "1234"
      $0.isSubmitButtonDisabled = false
    }
    store.send(.submitButtonTapped) {
      $0.isActivityIndicatorVisible = true
      $0.isFormDisabled = true
    }
    store.receive(.twoFactorResponse(.failure(.invalidTwoFactor))) {
      $0.alert = .init(
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
