import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class BindingFormTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: BindingForm.State(),
      reducer: BindingForm()
    )

    await store.send(.set(\.$sliderValue, 2)) {
      $0.sliderValue = 2
    }
    await store.send(.set(\.$stepCount, 1)) {
      $0.sliderValue = 1
      $0.stepCount = 1
    }
    await store.send(.set(\.$text, "Blob")) {
      $0.text = "Blob"
    }
    await store.send(.set(\.$toggleIsOn, true)) {
      $0.toggleIsOn = true
    }
    await store.send(.resetButtonTapped) {
      $0 = BindingForm.State(sliderValue: 5, stepCount: 10, text: "", toggleIsOn: false)
    }
  }
}
