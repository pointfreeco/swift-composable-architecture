import Perception
import SwiftUI
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
@MainActor
final class PerceptionTests: XCTestCase {
  func testRuntimeWarning_NotInPerceptionBody() {
    let model = Model()
    model.count += 1
    XCTAssertEqual(model.count, 1)
  }

  func testRuntimeWarning_InPerceptionBody_NotInSwiftUIBody() {
    let model = Model()
    PerceptionLocals.$isInPerceptionTracking.withValue(true) {
      _ = model.count
    }
  }

  func testRuntimeWarning_NotInPerceptionBody_InSwiftUIBody() {
    self.expectFailure()

    struct FeatureView: View {
      let model = Model()
      var body: some View {
        Text(self.model.count.description)
      }
    }
    self.render(FeatureView())
  }

  func testRuntimeWarning_InPerceptionBody_InSwiftUIBody() {
    struct FeatureView: View {
      let model = Model()
      var body: some View {
        WithPerceptionTracking {
          Text(self.model.count.description)
        }
      }
    }
    self.render(FeatureView())
  }

  func testRuntimeWarning_NotInPerceptionBody_SwiftUIBinding() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model()
      var body: some View {
        TextField("", text: self.$model.text)
      }
    }
    self.render(FeatureView())
  }

  func testRuntimeWarning_InPerceptionBody_SwiftUIBinding() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model()
      var body: some View {
        WithPerceptionTracking {
          TextField("", text: self.$model.text)
        }
      }
    }
    self.render(FeatureView())
  }

  private func expectFailure() {
    if #unavailable(iOS 17, macOS 14, tvOS 17, watchOS 10) {
      XCTExpectFailure {
        $0.compactDescription == """
          Perceptible state was accessed but is not being tracked. Track changes to state by \
          wrapping your view in a 'WithPerceptionTracking' view.
          """
      }
    }
  }

  private func render(_ view: some View) {
    _ = ImageRenderer(content: view).cgImage
  }
}

@Perceptible
private class Model {
  var count = 0
  var text = ""
}
