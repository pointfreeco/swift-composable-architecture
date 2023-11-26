import AppCore
import AuthenticationClient
import ComposableArchitecture
import LoginCore
import NewGameCore
import TwoFactorCore
import XCTest

@MainActor
final class AppCoreTests: XCTestCase {
  func testIntegration() async {
    let store = TestStore(initialState: TicTacToe.State()) {
      TicTacToe()
    } withDependencies: {
      $0.authenticationClient.login = { _ in
        AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
      }
    }

    await store.send(.login(.view(.set(\.$email, "blob@pointfree.co")))) {
      $0.modify(\.login) {
        $0.email = "blob@pointfree.co"
      }
    }
    await store.send(.login(.view(.set(\.$password, "bl0bbl0b")))) {
      $0.modify(\.login) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }
    await store.send(.login(.view(.loginButtonTapped))) {
      $0.modify(\.login) {
        $0.isLoginRequestInFlight = true
      }
    }
    await store.receive(\.login.loginResponse.success) {
      $0 = .newGame(NewGame.State())
    }
    await store.send(.newGame(.oPlayerNameChanged("Blob Sr."))) {
      $0.modify(\.newGame) {
        $0.oPlayerName = "Blob Sr."
      }
    }
    await store.send(.newGame(.logoutButtonTapped)) {
      $0 = .login(Login.State())
    }
  }

  func testIntegration_TwoFactor() async {
    let store = TestStore(initialState: TicTacToe.State()) {
      TicTacToe()
    } withDependencies: {
      $0.authenticationClient.login = { _ in
        AuthenticationResponse(token: "deadbeef", twoFactorRequired: true)
      }
      $0.authenticationClient.twoFactor = { _ in
        AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
      }
    }

    await store.send(.login(.view(.set(\.$email, "blob@pointfree.co")))) {
      $0.modify(\.login) {
        $0.email = "blob@pointfree.co"
      }
    }

    await store.send(.login(.view(.set(\.$password, "bl0bbl0b")))) {
      $0.modify(\.login) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }

    await store.send(.login(.view(.loginButtonTapped))) {
      $0.modify(\.login) {
        $0.isLoginRequestInFlight = true
      }
    }
    await store.receive(\.login.loginResponse.success) {
      $0.modify(\.login) {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = TwoFactor.State(token: "deadbeef")
      }
    }

    await store.send(.login(.twoFactor(.presented(.view(.set(\.$code, "1234")))))) {
      $0.modify(\.login) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      }
    }

    await store.send(.login(.twoFactor(.presented(.view(.submitButtonTapped))))) {
      $0.modify(\.login) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      }
    }
    await store.receive(\.login.twoFactor.twoFactorResponse.success) {
      $0 = .newGame(NewGame.State())
    }
  }
}
