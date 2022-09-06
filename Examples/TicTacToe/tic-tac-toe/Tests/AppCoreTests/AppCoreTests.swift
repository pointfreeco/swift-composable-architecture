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
    var authenticationClient = AuthenticationClient.unimplemented
    authenticationClient.login = { _ in
      AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
    }
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        authenticationClient: authenticationClient
      )
    )

    await store.send(.login(.emailChanged("blob@pointfree.co"))) {
      try (/AppState.login).modify(&$0) {
        $0.email = "blob@pointfree.co"
      }
    }
    await store.send(.login(.passwordChanged("bl0bbl0b"))) {
      try (/AppState.login).modify(&$0) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }
    await store.send(.login(.loginButtonTapped)) {
      try (/AppState.login).modify(&$0) {
        $0.isLoginRequestInFlight = true
      }
    }
    await store.receive(
      .login(
        .loginResponse(
          .success(AuthenticationResponse(token: "deadbeef", twoFactorRequired: false))
        )
      )
    ) {
      $0 = .newGame(NewGameState())
    }
    await store.send(.newGame(.oPlayerNameChanged("Blob Sr."))) {
      try (/AppState.newGame).modify(&$0) {
        $0.oPlayerName = "Blob Sr."
      }
    }
    await store.send(.newGame(.logoutButtonTapped)) {
      $0 = .login(LoginState())
    }
  }

  func testIntegration_TwoFactor() async {
    var authenticationClient = AuthenticationClient.unimplemented
    authenticationClient.login = { _ in
      AuthenticationResponse(token: "deadbeef", twoFactorRequired: true)
    }
    authenticationClient.twoFactor = { _ in
      AuthenticationResponse(token: "deadbeef", twoFactorRequired: false)
    }
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        authenticationClient: authenticationClient
      )
    )

    await store.send(.login(.emailChanged("blob@pointfree.co"))) {
      try (/AppState.login).modify(&$0) {
        $0.email = "blob@pointfree.co"
      }
    }

    await store.send(.login(.passwordChanged("bl0bbl0b"))) {
      try (/AppState.login).modify(&$0) {
        $0.password = "bl0bbl0b"
        $0.isFormValid = true
      }
    }

    await store.send(.login(.loginButtonTapped)) {
      try (/AppState.login).modify(&$0) {
        $0.isLoginRequestInFlight = true
      }
    }
    await store.receive(
      .login(
        .loginResponse(.success(AuthenticationResponse(token: "deadbeef", twoFactorRequired: true)))
      )
    ) {
      try (/AppState.login).modify(&$0) {
        $0.isLoginRequestInFlight = false
        $0.twoFactor = TwoFactorState(token: "deadbeef")
      }
    }

    await store.send(.login(.twoFactor(.codeChanged("1234")))) {
      try (/AppState.login).modify(&$0) {
        $0.twoFactor?.code = "1234"
        $0.twoFactor?.isFormValid = true
      }
    }

    await store.send(.login(.twoFactor(.submitButtonTapped))) {
      try (/AppState.login).modify(&$0) {
        $0.twoFactor?.isTwoFactorRequestInFlight = true
      }
    }
    await store.receive(
      .login(
        .twoFactor(
          .twoFactorResponse(
            .success(AuthenticationResponse(token: "deadbeef", twoFactorRequired: false))
          )
        )
      )
    ) {
      $0 = .newGame(NewGameState())
    }
  }
}
