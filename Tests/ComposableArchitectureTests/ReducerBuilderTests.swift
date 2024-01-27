// NB: This file contains compile-time tests to ensure reducer builder generic inference is working.

#if swift(>=5.9)
  import ComposableArchitecture
  import XCTest

  @Reducer
  private struct Test {
    struct State {}
    enum Action { case tap }

    var body: some Reducer<State, Action> {
      EmptyReducer()
    }

    @available(iOS, introduced: 9999)
    @available(macOS, introduced: 9999)
    @available(tvOS, introduced: 9999)
    @available(visionOS, introduced: 9999)
    @available(watchOS, introduced: 9999)
    @Reducer
    struct Unavailable {
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }
  }

  func testExistentialReducers() {
    _ = CombineReducers {
      Test()
      Test() as any ReducerOf<Test>
    }
  }

  func testLimitedAvailability() {
    _ = CombineReducers {
      Test()
      if #available(iOS 9999, macOS 9999, tvOS 9999, visionOS 9999, watchOS 9999, *) {
        Test.Unavailable()
      } else if #available(iOS 8888, macOS 8888, tvOS 8888, visionOS 8888, watchOS 8888, *) {
        EmptyReducer()
      }
    }
  }

  @Reducer
  private struct Root {
    struct State {
      var feature: Feature.State
      var optionalFeature: Feature.State?
      var enumFeature: Features.State?
      var features: IdentifiedArrayOf<Feature.State>
    }

    enum Action {
      case feature(Feature.Action)
      case optionalFeature(Feature.Action)
      case enumFeature(Features.Action)
      case features(IdentifiedActionOf<Feature>)
    }

    @available(iOS, introduced: 9999)
    @available(macOS, introduced: 9999)
    @available(tvOS, introduced: 9999)
    @available(visionOS, introduced: 9999)
    @available(watchOS, introduced: 9999)
    @Reducer
    struct Unavailable {
      let body = EmptyReducer<State, Action>()
    }

    var body: some ReducerOf<Self> {
      CombineReducers {
        Scope(state: \.feature, action: \.feature) {
          Feature()
          Feature()
        }
        Scope(state: \.feature, action: \.feature) {
          Feature()
          Feature()
        }
      }
      .ifLet(\.optionalFeature, action: \.optionalFeature) {
        Feature()
        Feature()
      }
      .ifLet(\.enumFeature, action: \.enumFeature) {
        EmptyReducer()
          .ifCaseLet(\.featureA, action: \.featureA) {
            Feature()
            Feature()
          }
          .ifCaseLet(\.featureB, action: \.featureB) {
            Feature()
            Feature()
          }

        Features()
      }
      .forEach(\.features, action: \.features) {
        Feature()
        Feature()
      }
    }

    @ReducerBuilder<State, Action>
    var testFlowControl: some ReducerOf<Self> {
      if true {
        Self()
      }

      if Bool.random() {
        Self()
      } else {
        EmptyReducer()
      }

      for _ in 1...10 {
        Self()
      }

      if #available(iOS 9999, macOS 9999, tvOS 9999, visionOS 9999, watchOS 9999, *) {
        Unavailable()
      }
    }

    @Reducer
    struct Feature {
      struct State: Identifiable {
        let id: Int
      }
      enum Action {
        case action
      }

      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    @Reducer
    struct Features {
      enum State {
        case featureA(Feature.State)
        case featureB(Feature.State)
      }

      enum Action {
        case featureA(Feature.Action)
        case featureB(Feature.Action)
      }

      var body: some ReducerOf<Self> {
        Scope(state: \.featureA, action: \.featureA) {
          Feature()
        }
        Scope(state: \.featureB, action: \.featureB) {
          Feature()
        }
      }
    }
  }

  @Reducer
  private struct IfLetExample {
    struct State {
      var optional: Int?
    }

    enum Action {}

    var body: some ReducerOf<Self> {
      EmptyReducer().ifLet(\.optional, action: \.self) { EmptyReducer() }
    }
  }

  @Reducer
  private struct IfCaseLetExample {
    enum State {
      case value(Int)
    }

    enum Action {}

    var body: some ReducerOf<Self> {
      EmptyReducer().ifCaseLet(\.value, action: \.self) { EmptyReducer() }
    }
  }

  @Reducer
  private struct ForEachExample {
    struct Element: Identifiable { let id: Int }

    struct State {
      var values: IdentifiedArrayOf<Element>
    }

    enum Action {
      case value(IdentifiedAction<Element.ID, Never>)
    }

    var body: some ReducerOf<Self> {
      EmptyReducer().forEach(\.values, action: \.value) { EmptyReducer() }
    }
  }

  @Reducer
  private struct ScopeIfLetExample {
    struct State {
      var optionalSelf: Self? {
        get { self }
        set { newValue.map { self = $0 } }
      }
    }

    enum Action {}

    var body: some ReducerOf<Self> {
      Scope(state: \.self, action: \.self) {
        EmptyReducer()
          .ifLet(\.optionalSelf, action: \.self) {
            EmptyReducer()
          }
      }
    }
  }
#endif
