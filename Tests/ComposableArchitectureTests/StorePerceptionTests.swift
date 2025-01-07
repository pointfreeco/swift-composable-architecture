@_spi(Logging) import ComposableArchitecture
import SwiftUI
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
final class StorePerceptionTests: BaseTCATestCase {
  override func setUpWithError() throws {
    try checkAvailability()
  }

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
      let previous = Perception.isPerceptionCheckingEnabled
      Perception.isPerceptionCheckingEnabled = true
      defer { Perception.isPerceptionCheckingEnabled = previous }
      XCTExpectFailure {
        render(FeatureView())
      } issueMatcher: {
        $0.compactDescription == """
          failed - Perceptible state was accessed but is not being tracked. Track changes to state by \
          wrapping your view in a 'WithPerceptionTracking' view. This must also be done for any \
          escaping, trailing closures, such as 'GeometryReader', `LazyVStack` (and all lazy \
          views), navigation APIs ('sheet', 'popover', 'fullScreenCover', etc.), and others.
          """
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
  private func render(_ view: some View) {
    let image = ImageRenderer(content: view).cgImage
    _ = image
  }
}

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

// NB: Workaround to XCTest ignoring `@available(...)` attributes.
private func checkAvailability() throws {
  guard #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) else {
    throw XCTSkip("Requires iOS 16, macOS 13, tvOS 16, or watchOS 9")
  }
}
