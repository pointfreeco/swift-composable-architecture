import AuthenticationClient
import ComposableArchitecture
import TwoFactorCore
import XCTest

@MainActor
class TwoFactorCoreTests: XCTestCase {
  func testFlow_Success() async {
    let store = TestStore(
      initialState: TwoFactor.State(token: "deadbeefdeadbeef"),
      reducer: TwoFactor(tearDownToken: Never.self)
        .dependency(\.mainQueue, .immediate)
        .dependency(\.authenticationClient.twoFactor) { _ in
          AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
        }
    )

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
      $0.isFormValid = true
    }
    store.send(.submitButtonTapped) {
      $0.isTwoFactorRequestInFlight = true
    }
    await store.receive(
      .twoFactorResponse(
        .success(AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false))
      )
    ) {
      $0.isTwoFactorRequestInFlight = false
    }
  }

  func testFlow_Failure() async {
    let store = TestStore(
      initialState: TwoFactor.State(token: "deadbeefdeadbeef"),
      reducer: TwoFactor(tearDownToken: Never.self)
        .dependency(\.mainQueue, .immediate)
        .dependency(\.authenticationClient.twoFactor) { _ in
          throw AuthenticationError.invalidTwoFactor
        }
    )

    store.send(.codeChanged("1234")) {
      $0.code = "1234"
      $0.isFormValid = true
    }
    store.send(.submitButtonTapped) {
      $0.isTwoFactorRequestInFlight = true
    }
    await store.receive(.twoFactorResponse(.failure(AuthenticationError.invalidTwoFactor))) {
      $0.alert = AlertState(
        title: TextState(AuthenticationError.invalidTwoFactor.localizedDescription)
      )
      $0.isTwoFactorRequestInFlight = false
    }
    store.send(.alertDismissed) {
      $0.alert = nil
    }
  }
}
