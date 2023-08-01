// NB: This file contains compile-time tests to ensure reducer builder generic inference is working.

import ComposableArchitecture
import XCTest

private struct Test: Reducer {
  struct State {}
  enum Action { case tap }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    .none
  }

  @available(iOS, introduced: 9999)
  struct Unavailable: Reducer {
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
      .none
    }
  }
}

func testLimitedAvailability() {
  _ = CombineReducers {
    Test()
    if #available(iOS 9999, *) {
      Test.Unavailable()
    } else if #available(iOS 8888, *) {
      EmptyReducer()
    }
  }
}

private struct Root: Reducer {
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
    case features(id: Feature.State.ID, feature: Feature.Action)
  }

  @available(iOS, introduced: 9999)
  struct Unavailable: Reducer {
    let body = EmptyReducer<State, Action>()
  }

  var body: some ReducerOf<Self> {
    CombineReducers {
      Scope(state: \.feature, action: /Action.feature) {
        Feature()
        Feature()
      }
      Scope(state: \.feature, action: /Action.feature) {
        Feature()
        Feature()
      }
    }
    .ifLet(\.optionalFeature, action: /Action.optionalFeature) {
      Feature()
      Feature()
    }
    .ifLet(\.enumFeature, action: /Action.enumFeature) {
      EmptyReducer()
        .ifCaseLet(/Features.State.featureA, action: /Features.Action.featureA) {
          Feature()
          Feature()
        }
        .ifCaseLet(/Features.State.featureB, action: /Features.Action.featureB) {
          Feature()
          Feature()
        }

      Features()
    }
    .forEach(\.features, action: /Action.features) {
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

    if #available(iOS 9999, *) {
      Unavailable()
    }
  }

  struct Feature: Reducer {
    struct State: Identifiable {
      let id: Int
    }
    enum Action {
      case action
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
      .none
    }
  }

  struct Features: Reducer {
    enum State {
      case featureA(Feature.State)
      case featureB(Feature.State)
    }

    enum Action {
      case featureA(Feature.Action)
      case featureB(Feature.Action)
    }

    var body: some ReducerOf<Self> {
      Scope(state: /State.featureA, action: /Action.featureA) {
        Feature()
      }
      Scope(state: /State.featureB, action: /Action.featureB) {
        Feature()
      }
    }
  }
}

private struct IfLetExample: Reducer {
  struct State {
    var optional: Int?
  }

  enum Action {}

  var body: some ReducerOf<Self> {
    EmptyReducer().ifLet(\.optional, action: .self) { EmptyReducer() }
  }
}

private struct IfCaseLetExample: Reducer {
  enum State {
    case value(Int)
  }

  enum Action {}

  var body: some ReducerOf<Self> {
    EmptyReducer().ifCaseLet(/State.value, action: .self) { EmptyReducer() }
  }
}

private struct ForEachExample: Reducer {
  struct Element: Identifiable { let id: Int }

  struct State {
    var values: IdentifiedArrayOf<Element>
  }

  enum Action {
    case value(id: Element.ID, action: Never)
  }

  var body: some ReducerOf<Self> {
    EmptyReducer().forEach(\.values, action: /Action.value) { EmptyReducer() }
  }
}

private struct ScopeIfLetExample: Reducer {
  struct State {
    var optionalSelf: Self? {
      get { self }
      set { newValue.map { self = $0 } }
    }
  }

  enum Action {}

  var body: some ReducerOf<Self> {
    Scope(state: \.self, action: .self) {
      EmptyReducer()
        .ifLet(\.optionalSelf, action: .self) {
          EmptyReducer()
        }
    }
  }
}
