import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

class BindingFormTests: XCTestCase {
  func testBasics() {
    let store = TestStore(
      initialState: BindingFormState(),
      reducer: bindingFormReducer,
      environment: BindingFormEnvironment()
    )

    store.send(.set(\.$sliderValue, 2)) {
      $0.sliderValue = 2
    }
    store.send(.set(\.$stepCount, 1)) {
      $0.sliderValue = 1
      $0.stepCount = 1
    }
    store.send(.set(\.$text, "Blob")) {
      $0.text = "Blob"
    }
    store.send(.set(\.$toggleIsOn, true)) {
      $0.toggleIsOn = true
    }
    store.send(.resetButtonTapped) {
      $0 = BindingFormState(sliderValue: 5, stepCount: 10, text: "", toggleIsOn: false)
    }
  }
}
