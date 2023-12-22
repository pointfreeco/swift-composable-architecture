@_spi(Logging) import ComposableArchitecture
import SwiftUI
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
@MainActor
final class StorePerceptionTests: BaseTCATestCase {
  func testPerceptionCheck_SkipWhenNonInViewBody() {
    let store = Store(initialState: Feature.State()) {
      Feature()
    }

    store.send(.tap)
  }

//  func testPerceptionCheck_SkipWhenNonInView() {
//    struct FeatureView: View {
//      let store = Store(initialState: Feature.State()) {
//        Feature()
//      }
//      var body: some View {
//        Text("Hi")
//          .onAppear { store.send(.tap) }
//      }
//    }
//    render(FeatureView())
//  }

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
