import ComposableArchitecture
import XCTest

@MainActor
final class DependencyKeyWritingReducerTests: XCTestCase {
  func testWritingFusion() async {
    let reducer: _DependencyKeyWritingReducer<Feature> = Feature()
      .dependency(\.myValue, 42)
    let _: _DependencyKeyWritingReducer<Feature> =
      reducer
      .dependency(\.myValue, 1729)
      .dependency(\.myValue, 1)
      .dependency(\.myValue, 2)
      .dependency(\.myValue, 3)
  }

  func testWritingFusionOrder() async {
    let reducer = Feature()
      .dependency(\.myValue, 42)
      .dependency(\.myValue, 1729)

    let store = TestStore(
      initialState: Feature.State(),
      reducer: reducer
    )

    await store.send(.tap) {
      $0.value = 42
    }
  }

  func testWritingOrder() async {
    let reducer = CombineReducers {
      Feature()
        .dependency(\.myValue, 42)
    }
    .dependency(\.myValue, 1729)

    let store = TestStore(
      initialState: Feature.State(),
      reducer: reducer
    )

    await store.send(.tap) {
      $0.value = 42
    }
  }

  func testDependency_EffectOfEffect() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable { var count = 0 }
      enum Action: Equatable {
        case tap
        case response(Int)
        case otherResponse(Int)
      }
      @Dependency(\.myValue) var myValue

      func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .tap:
          state.count += 1
          return .task { .response(self.myValue) }

        case let .response(value):
          state.count = value
          return .task { .otherResponse(self.myValue) }

        case let .otherResponse(value):
          state.count = value
          return .none
        }
      }
    }

    let store = TestStore(
      initialState: Feature.State(),
      reducer: Feature()
        .dependency(\.myValue, 42)
    )

    await store.send(.tap) {
      $0.count = 1
    }
    await store.receive(.response(42)) {
      $0.count = 42
    }
    await store.receive(.otherResponse(42))
  }
}

private struct Feature: ReducerProtocol {
  @Dependency(\.myValue) var myValue
  struct State: Equatable { var value = 0 }
  enum Action { case tap }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .tap:
      state.value = self.myValue
      return .none
    }
  }
}

private enum MyValue: DependencyKey {
  static let liveValue = 0
  static let testValue = 0
}
extension DependencyValues {
  var myValue: Int {
    get { self[MyValue.self] }
    set { self[MyValue.self] = newValue }
  }
}
