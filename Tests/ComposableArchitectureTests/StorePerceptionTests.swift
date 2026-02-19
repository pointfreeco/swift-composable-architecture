@_spi(Logging) import ComposableArchitecture
import SwiftUI
import XCTest

final class StorePerceptionTests: BaseTCATestCase {
  @MainActor
  func testPerceptionCheck_SkipWhenOutsideView() {
    let store = Store(initialState: Feature.State()) {
      Feature()
    }
    store.send(.tap)
  }

  @MainActor
  func testPerceptionCheck_SkipWhenActionClosureOfView() {
    @MainActor
    struct FeatureView: View {
      let store = Store(initialState: Feature.State()) {
        Feature()
      }
      var body: some View {
        Text("Hi")
          .onAppear { store.send(.tap) }
      }
    }
    render(FeatureView())
  }

  @MainActor
  @available(*, deprecated)
  func testPerceptionCheck_AccessStateWithoutTracking() {
    @MainActor
    struct FeatureView: View {
      let store = Store(initialState: Feature.State()) {
        Feature()
      }
      var body: some View {
        Text(store.count.description)
      }
    }
    #if DEBUG && !os(visionOS)
      XCTExpectFailure {
        render(FeatureView())
      } issueMatcher: {
        $0.compactDescription.contains("Perceptible state was accessed")
      }
    #endif
  }

  @MainActor
  func testPerceptionCheck_AccessStateWithTracking() {
    @MainActor
    struct FeatureView: View {
      let store = Store(initialState: Feature.State()) {
        Feature()
      }
      var body: some View {
        WithPerceptionTracking {
          Text(store.count.description)
        }
      }
    }
    render(FeatureView())
  }

  @MainActor
  func testPerceptionCheck_ViewRepresentable_publisher() {
    #if canImport(UIKit)
      struct ViewRepresentable: UIViewRepresentable {
        let store = Store(initialState: Feature.State()) {
          Feature()
        }
        func makeUIView(context: Context) -> UILabel {
          let label = UILabel()
          let cancellable = store.publisher.sink { [weak label] state in
            label?.text = "\(state.count)"
          }
          objc_setAssociatedObject(
            label, cancellableKey, cancellable, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
          return label
        }
        func updateUIView(_ view: UILabel, context: Context) {}
      }
      render(ViewRepresentable())
    #endif
  }

  @MainActor
  private func render(_ view: some View) {
    let image = ImageRenderer(content: view).cgImage
    _ = image
  }
}

@MainActor private let cancellableKey = malloc(1)!

@Reducer
private struct Feature {
  @ObservableState
  struct State {
    var count = 0
  }
  enum Action { case tap }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      state.count += 1
      return .none
    }
  }
}
