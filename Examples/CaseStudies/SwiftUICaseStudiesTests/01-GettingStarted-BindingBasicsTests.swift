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

    store.assert(
      .send(.form(.set(\.sliderValue, 2))) {
        $0.sliderValue = 2
      },
      .send(.form(.set(\.stepCount, 1))) {
        $0.sliderValue = 1
        $0.stepCount = 1
      },
      .send(.form(.set(\.text, "Blob"))) {
        $0.text = "Blob"
      },
      .send(.form(.set(\.toggleIsOn, true))) {
        $0.toggleIsOn = true
      },
      .send(.resetButtonTapped) {
        $0 = .init(sliderValue: 5, stepCount: 10, text: "", toggleIsOn: false)
      }
    )
  }
}
