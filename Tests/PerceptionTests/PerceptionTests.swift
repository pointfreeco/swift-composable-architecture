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
        VStack {
          TextField("", text: self.$model.text)
        }
      }
    }
    self.render(FeatureView())
  }

  func testRuntimeWarning_InPerceptionBody_SwiftUIBinding() {
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

  func testRuntimeWarning_NotInPerceptionBody_ForEach() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model(
        list: [
          Model(count: 1),
          Model(count: 2),
          Model(count: 3),
        ]
      )
      var body: some View {
        ForEach(model.list) { model in
          Text(model.count.description)
        }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_InnerInPerceptionBody_ForEach() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model(
        list: [
          Model(count: 1),
          Model(count: 2),
          Model(count: 3),
        ]
      )
      var body: some View {
        ForEach(model.list) { model in
          WithPerceptionTracking {
            Text(model.count.description)
          }
        }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_OuterInPerceptionBody_ForEach() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model(
        list: [
          Model(count: 1),
          Model(count: 2),
          Model(count: 3),
        ]
      )
      var body: some View {
        WithPerceptionTracking {
          ForEach(model.list) { model in
            Text(model.count.description)
          }
        }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_OuterAndInnerInPerceptionBody_ForEach() {
    struct FeatureView: View {
      @State var model = Model(
        list: [
          Model(count: 1),
          Model(count: 2),
          Model(count: 3),
        ]
      )
      var body: some View {
        WithPerceptionTracking {
          ForEach(model.list) { model in
            WithPerceptionTracking {
              Text(model.count.description)
            }
          }
        }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_NotInPerceptionBody_Sheet() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model(child: Model())
      var body: some View {
        Text("Parent")
          .sheet(item: $model.child) { child in
            Text(child.count.description)
          }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_InnerInPerceptionBody_Sheet() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model(child: Model())
      var body: some View {
        Text("Parent")
          .sheet(item: $model.child) { child in
            WithPerceptionTracking {
              Text(child.count.description)
            }
          }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_OuterInPerceptionBody_Sheet() {
    self.expectFailure()

    struct FeatureView: View {
      @State var model = Model(child: Model())
      var body: some View {
        WithPerceptionTracking {
          Text("Parent")
            .sheet(item: $model.child) { child in
              Text(child.count.description)
            }
        }
      }
    }

    self.render(FeatureView())
  }

  func testRuntimeWarning_OuterAndInnerInPerceptionBody_Sheet() {
    struct FeatureView: View {
      @State var model = Model(child: Model())
      var body: some View {
        WithPerceptionTracking {
          Text("Parent")
            .sheet(item: $model.child) { child in
              WithPerceptionTracking {
                Text(child.count.description)
              }
            }
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
    let image = ImageRenderer(content: view).cgImage
    _ = image
  }
}

@Perceptible
private class Model: Identifiable {
  var child: Model?
  var count: Int
  var list: [Model]
  var text: String

  init(
    child: Model? = nil,
    count: Int = 0,
    list: [Model] = [],
    text: String = ""
  ) {
    self.child = child
    self.count = count
    self.list = list
    self.text = text
  }
}
