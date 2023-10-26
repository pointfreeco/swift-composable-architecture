import ComposableArchitecture
import XCTest

@MainActor
final class DependencyKeyWritingReducerTests: BaseTCATestCase {
  func testWritingFusion() async {
    let reducer: _DependencyKeyWritingReducer<Feature> = Feature()
      .dependency(\.myValue, 42)
      .dependency(\.myValue, 1729)
      .dependency(\.myValue, 1)
      .dependency(\.myValue, 2)
      .dependency(\.myValue, 3)

    XCTAssertTrue((reducer as Any) is _DependencyKeyWritingReducer<Feature>)
  }

  func testTransformFusion() async {
    let reducer: _DependencyKeyWritingReducer<Feature> = Feature()
      .transformDependency(\.myValue) { $0 = 42 }
      .transformDependency(\.myValue) { $0 = 1729 }
      .transformDependency(\.myValue) { $0 = 1 }
      .transformDependency(\.myValue) { $0 = 2 }
      .transformDependency(\.myValue) { $0 = 3 }

    XCTAssertTrue((reducer as Any) is _DependencyKeyWritingReducer<Feature>)
  }

  func testWritingFusionOrder() async {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
        .dependency(\.myValue, 42)
        .dependency(\.myValue, 1729)
    }

    await store.send(.tap) {
      $0.value = 42
    }
  }

  func testTransformFusionOrder() async {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
        .transformDependency(\.myValue) { $0 = 42 }
        .transformDependency(\.myValue) { $0 = 1729 }
    }

    await store.send(.tap) {
      $0.value = 42
    }
  }

  func testWritingOrder() async {
    let store = TestStore(initialState: Feature.State()) {
      CombineReducers {
        Feature()
          .dependency(\.myValue, 42)
      }
      .dependency(\.myValue, 1729)
    }

    await store.send(.tap) {
      $0.value = 42
    }
  }

  func testTransformOrder() async {
    let store = TestStore(initialState: Feature.State()) {
      CombineReducers {
        Feature()
          .transformDependency(\.myValue) { $0 = 42 }
      }
      .transformDependency(\.myValue) { $0 = 1729 }
    }

    await store.send(.tap) {
      $0.value = 42
    }
  }

  @Reducer
  fileprivate struct Feature_testDependency_EffectOfEffect {
    struct State: Equatable { var count = 0 }
    enum Action: Equatable {
      case tap
      case response(Int)
      case otherResponse(Int)
    }
    @Dependency(\.myValue) var myValue

    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .tap:
          state.count += 1
          return .run { send in await send(.response(self.myValue)) }

        case let .response(value):
          state.count = value
          return .run { send in await send(.otherResponse(self.myValue)) }

        case let .otherResponse(value):
          state.count = value
          return .none
        }
      }
    }
  }
  func testDependency_EffectOfEffect() async {
    let store = TestStore(initialState: Feature_testDependency_EffectOfEffect.State()) {
      Feature_testDependency_EffectOfEffect()
        .dependency(\.myValue, 42)
    }

    await store.send(.tap) {
      $0.count = 1
    }
    await store.receive(.response(42)) {
      $0.count = 42
    }
    await store.receive(.otherResponse(42))
  }
}

@Reducer
private struct Feature {
  @Dependency(\.myValue) var myValue
  struct State: Equatable { var value = 0 }
  enum Action { case tap }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .tap:
        state.value = self.myValue
        return .none
      }
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
