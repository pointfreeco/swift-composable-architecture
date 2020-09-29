import AuthenticationClient
import Combine
import ComposableArchitecture
import TicTacToeCommon
import TwoFactorCore
import XCTest

@testable import TwoFactorSwiftUI

class TwoFactorSwiftUITests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

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
        mainQueue: AnyScheduler(self.scheduler)
      )
    )
    .scope(state: { $0.view }, action: TwoFactorAction.view)

    store.assert(
      .environment {
        $0.authenticationClient.twoFactor = { _ in
          Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
        }
      },
      .send(.codeChanged("1")) {
        $0.code = "1"
      },
      .send(.codeChanged("12")) {
        $0.code = "12"
      },
      .send(.codeChanged("123")) {
        $0.code = "123"
      },
      .send(.codeChanged("1234")) {
        $0.code = "1234"
        $0.isSubmitButtonDisabled = false
      },
      .send(.submitButtonTapped) {
        $0.isActivityIndicatorVisible = true
        $0.isFormDisabled = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(
        .twoFactorResponse(.success(.init(token: "deadbeefdeadbeef", twoFactorRequired: false)))
      ) {
        $0.isActivityIndicatorVisible = false
        $0.isFormDisabled = false
      }
    )
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
        mainQueue: AnyScheduler(self.scheduler)
      )
    )
    .scope(state: { $0.view }, action: TwoFactorAction.view)

    store.assert(
      .send(.codeChanged("1234")) {
        $0.code = "1234"
        $0.isSubmitButtonDisabled = false
      },
      .send(.submitButtonTapped) {
        $0.isActivityIndicatorVisible = true
        $0.isFormDisabled = true
      },
      .do {
        self.scheduler.advance()
      },
      .receive(.twoFactorResponse(.failure(.invalidTwoFactor))) {
        $0.alert = .init(title: .init(AuthenticationError.invalidTwoFactor.localizedDescription))
        $0.isActivityIndicatorVisible = false
        $0.isFormDisabled = false
      },
      .send(.alertDismissed) {
        $0.alert = nil
      }
    )
  }
}
