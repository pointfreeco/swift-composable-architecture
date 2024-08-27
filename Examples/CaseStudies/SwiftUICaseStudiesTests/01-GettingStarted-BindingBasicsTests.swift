import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class BindingFormTests: XCTestCase {
  func testBasics() async {
    let store = await TestStore(initialState: BindingForm.State()) {
      BindingForm()
    }

    await store.send(\.binding.sliderValue, 2) {
      $0.sliderValue = 2
    }
    await store.send(\.binding.stepCount, 1) {
      $0.sliderValue = 1
      $0.stepCount = 1
    }
    await store.send(\.binding.text, "Blob") {
      $0.text = "Blob"
    }
    await store.send(\.binding.toggleIsOn, true) {
      $0.toggleIsOn = true
    }
    await store.send(.resetButtonTapped) {
      $0 = BindingForm.State(sliderValue: 5, stepCount: 10, text: "", toggleIsOn: false)
    }
  }
}
