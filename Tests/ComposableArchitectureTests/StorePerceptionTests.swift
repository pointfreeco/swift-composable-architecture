#if swift(>=5.9)
  @_spi(Logging) import ComposableArchitecture
  import SwiftUI
  import XCTest

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
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
      if #unavailable(iOS 17, macOS 14, tvOS 17, watchOS 10) {
        struct FeatureView: View {
          let store = Store(initialState: Feature.State()) {
            Feature()
          }
          var body: some View {
            Text(store.count.description)
          }
        }
        XCTExpectFailure {
          render(FeatureView())
        } issueMatcher: {
          $0.compactDescription == """
            Perceptible state was accessed but is not being tracked. Track changes to state by \
            wrapping your view in a 'WithPerceptionTracking' view.
            """
        }
      }
    }

    @MainActor
    func testPerceptionCheck_AccessStateWithTracking() {
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
#endif
