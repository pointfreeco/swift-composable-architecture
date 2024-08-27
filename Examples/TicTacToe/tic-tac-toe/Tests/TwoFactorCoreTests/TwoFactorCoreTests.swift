import AuthenticationClient
import ComposableArchitecture
import TwoFactorCore
import XCTest

final class TwoFactorCoreTests: XCTestCase {
  func testFlow_Success() async {
    let store = await TestStore(initialState: TwoFactor.State(token: "deadbeefdeadbeef")) {
      TwoFactor()
    } withDependencies: {
      $0.authenticationClient.twoFactor = { @Sendable _, _ in
        AuthenticationResponse(token: "deadbeefdeadbeef", twoFactorRequired: false)
      }
    }

    await store.send(\.view.binding.code, "1") {
      $0.code = "1"
    }
    await store.send(\.view.binding.code, "12") {
      $0.code = "12"
    }
    await store.send(\.view.binding.code, "123") {
      $0.code = "123"
    }
    await store.send(\.view.binding.code, "1234") {
      $0.code = "1234"
      $0.isFormValid = true
    }
    await store.send(\.view.submitButtonTapped) {
      $0.isTwoFactorRequestInFlight = true
    }
    await store.receive(\.twoFactorResponse.success) {
      $0.isTwoFactorRequestInFlight = false
    }
  }

  func testFlow_Failure() async {
    let store = await TestStore(initialState: TwoFactor.State(token: "deadbeefdeadbeef")) {
      TwoFactor()
    } withDependencies: {
      $0.authenticationClient.twoFactor = { @Sendable _, _ in
        throw AuthenticationError.invalidTwoFactor
      }
    }

    await store.send(\.view.binding.code, "1234") {
      $0.code = "1234"
      $0.isFormValid = true
    }
    await store.send(\.view.submitButtonTapped) {
      $0.isTwoFactorRequestInFlight = true
    }
    await store.receive(\.twoFactorResponse.failure) {
      $0.alert = AlertState {
        TextState(AuthenticationError.invalidTwoFactor.localizedDescription)
      }
      $0.isTwoFactorRequestInFlight = false
    }
    await store.send(\.alert.dismiss) {
      $0.alert = nil
    }
    await store.finish()
  }
}
