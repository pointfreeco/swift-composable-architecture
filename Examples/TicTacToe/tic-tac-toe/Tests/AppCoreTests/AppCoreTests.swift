import AppCore
import AuthenticationClient
import ComposableArchitecture
import LoginCore
import NewGameCore
import Testing
import TwoFactorCore

@MainActor
struct AppCoreTests {
  @Test
  func integration() async {
    let store = TestStore(initialState: TicTacToe.State.login(Login.State())) {
      TicTacToe.body
    } withDependencies: {
      $0.authenticationClient.login = { @Sendable _, _ in
        AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
      }
    }

    await store.send(\.login.view.binding.email, "blob@pointfree.co") {
      $0.modify(\.login) { $0.email = "blob@pointfree.co" }
    }
    await store.send(\.login.view.binding.password, "bl0bbl0b") {
      $0.modify(\.login) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }
    await store.send(\.login.view.loginButtonTapped) {
      $0.modify(\.login) { $0.isLoginRequestInFlight = true }
    }
    await store.receive(\.login.loginResponse.success) {
      $0 = .newGame(NewGame.State())
    }
    await store.send(\.newGame.binding.oPlayerName, "Blob Sr.") {
      $0.modify(\.newGame) { $0.oPlayerName = "Blob Sr." }
    }
    await store.send(\.newGame.logoutButtonTapped) {
      $0 = .login(Login.State())
    }
  }

  @Test
  func twoFactor() async {
    let store = TestStore(initialState: TicTacToe.State.login(Login.State())) {
      TicTacToe.body
    } withDependencies: {
      $0.authenticationClient.login = { @Sendable _, _ in
        AuthenticationResponse(token: "deadbeef", twoFactorRequired: true)
      }
      $0.authenticationClient.twoFactor = { @Sendable _, _ in
        AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
      }
    }

    await store.send(\.login.view.binding.email, "blob@pointfree.co") {
      $0.modify(\.login) { $0.email = "blob@pointfree.co" }
    }

    await store.send(\.login.view.binding.password, "bl0bbl0b") {
      $0.modify(\.login) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }

    await store.send(\.login.view.loginButtonTapped) {
      $0.modify(\.login) { $0.isLoginRequestInFlight = true }
    }
    await store.receive(\.login.loginResponse.success) {
      $0.modify(\.login) {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = TwoFactor.State(token: "deadbeef")
      }
    }

    await store.send(\.login.twoFactor.view.binding.code, "1234") {
      $0.modify(\.login) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      }
    }

    await store.send(\.login.twoFactor.view.submitButtonTapped) {
      $0.modify(\.login) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      }
    }
    .finish()
    await store.receive(\.login.twoFactor.twoFactorResponse.success) {
      $0 = .newGame(NewGame.State())
    }
  }
}
