import AuthenticationClient
import Combine
import ComposableArchitecture
import TwoFactorCore
import XCTest

@testable import TwoFactorSwiftUI

class TwoFactorSwiftUITests: XCTestCase {
  func testFlow_Success() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.twoFactor = { _ in
      Effect(value: .init(token: "deadbeefdeadbeef", twoFactorRequired: false))
    }
    let mainQueue = DispatchQueue.test

    let store = Store(
      initialState: TwoFactorState(token: "deadbeefdeadbeef"),
      reducer: twoFactorReducer,
      environment: TwoFactorEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )
    let viewStore = ViewStore(
      store.scope(state: TwoFactorView.ViewState.init, action: TwoFactorAction.init)
    )

    viewStore.send(.codeChanged("1"))
    XCTAssertNoDifference(
      .init(
        code: "1",
        isActivityIndicatorVisible: false,
        isFormDisabled: false,
        isSubmitButtonDisabled: true
      ),
      viewStore.state
    )

    viewStore.send(.codeChanged("12"))
    XCTAssertEqual("12", viewStore.code)

    viewStore.send(.codeChanged("123"))
    XCTAssertEqual("123", viewStore.code)

    viewStore.send(.codeChanged("1234"))
    XCTAssertEqual("1234", viewStore.code)
    XCTAssertEqual(false, viewStore.isSubmitButtonDisabled)

    viewStore.send(.submitButtonTapped)
    XCTAssertEqual(true, viewStore.isActivityIndicatorVisible)
    XCTAssertEqual(true, viewStore.isFormDisabled)
  }

  func testFlow_Failure() {
    var authenticationClient = AuthenticationClient.failing
    authenticationClient.twoFactor = { _ in Effect(error: .invalidTwoFactor) }
    let mainQueue = DispatchQueue.test

    let store = Store(
      initialState: TwoFactorState(token: "deadbeefdeadbeef"),
      reducer: twoFactorReducer,
      environment: TwoFactorEnvironment(
        authenticationClient: authenticationClient,
        mainQueue: mainQueue.eraseToAnyScheduler()
      )
    )
    let viewStore = ViewStore(
      store.scope(state: TwoFactorView.ViewState.init, action: TwoFactorAction.init)
    )

    viewStore.send(.codeChanged("1234"))
    viewStore.send(.submitButtonTapped)
    XCTAssertEqual(true, viewStore.isActivityIndicatorVisible)
    XCTAssertEqual(true, viewStore.isFormDisabled)

    mainQueue.advance()

    XCTAssertNoDifference(
      .init(title: TextState(AuthenticationError.invalidTwoFactor.localizedDescription)),
      viewStore.alert
    )
    XCTAssertEqual(false, viewStore.isActivityIndicatorVisible)
    XCTAssertEqual(false, viewStore.isFormDisabled)

    viewStore.send(.alertDismissed)
    XCTAssertEqual(nil, viewStore.alert)
  }
}
