import XCTest

// Copy/Pasted from `Integration. For some reason, can't be imported.
enum AnimationCaseTag: String {
  case observedObject = "OO"
  case viewStore = "VS"
}

enum AnimationCase: String, CaseIterable, Hashable {
  case none
  case observeValue
  case animatedBinding
  case observeValue_BindingAnimation
  case observeValue_Transaction
  case observeValue_Transaction_BindingAnimation
  case observeValue_Binding_Transaction
  case observeValue_Transaction_Binding_Transaction
}

extension AnimationCase {
  var accessibilityLabel: String { self.rawValue }
  func toggleAccessibilityLabel(tag: AnimationCaseTag) -> String {
    self.rawValue + "_Toggle_" + tag.rawValue
  }
  func effectiveAnimationDurationAccessibilityLabel(tag: AnimationCaseTag) -> String {
    self.rawValue + "_Result_" + tag.rawValue
  }
}
extension AnimationCase {
  var expectedDuration: String {
    switch self {
    case .none:
      return "None"
    case .observeValue:
      return "0.7"
    case .animatedBinding:
      return "0.2"
    case .observeValue_BindingAnimation:
      return "0.7"
    case .observeValue_Transaction:
      return "0.9"
    case .observeValue_Transaction_BindingAnimation:
      return "0.9"
    case .observeValue_Binding_Transaction:
      return "0.7"
    case .observeValue_Transaction_Binding_Transaction:
      return "0.9"
    }
  }
}

final class BindingsAnimationsTests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() throws {

    let app = XCUIApplication()
    app.launch()
    let collectionViewsQuery = app.collectionViews
    collectionViewsQuery.buttons["BindingsAnimationsTestCase"].tap()

    func reset() {
      app.buttons["Reset"].tap()
    }

    func next() {
      app.buttons["Next"].tap()
    }

    func value(_ animationCase: AnimationCase, _ tag: AnimationCaseTag) -> String? {
      collectionViewsQuery.staticTexts[
        animationCase.effectiveAnimationDurationAccessibilityLabel(tag: tag)
      ].value as? String
    }

    func tap(_ animationCase: AnimationCase, _ tag: AnimationCaseTag) {
      collectionViewsQuery.switches[animationCase.toggleAccessibilityLabel(tag: tag)].tap()
    }

    for animationCase in AnimationCase.allCases {
      reset()
      
      XCTAssertEqual("?", value(animationCase, .observedObject))
      XCTAssertEqual("?", value(animationCase, .viewStore))
      
      tap(animationCase, .observedObject)
      tap(animationCase, .viewStore)
      
      Thread.sleep(forTimeInterval: 1)
      
      XCTAssertEqual(animationCase.expectedDuration, value(animationCase, .observedObject))
      XCTAssertEqual(animationCase.expectedDuration, value(animationCase, .viewStore))
      
      next()
    }
  }
}
