// NB: This file contains compile-time tests to ensure reducer builder generic inference is working.

import ComposableArchitecture
import XCTest

private struct Test: ReducerProtocol {
  struct State {}
  enum Action { case tap }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    .none
  }

  @available(iOS, introduced: 9999.0)
  struct Unavailable: ReducerProtocol {
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      .none
    }
  }
}

func testLimitedAvailability() {
  _ = CombineReducers {
    Test()
    if #available(iOS 9999.0, *) {
      Test.Unavailable()
    } else if #available(iOS 8888.0, *) {
      EmptyReducer()
    }
  }
}

private struct Root: ReducerProtocol {
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

  @available(iOS, introduced: 9999.0)
  struct Unavailable: ReducerProtocol {
    let body = EmptyReducer<State, Action>()
  }

  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
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
    var testFlowControl: some ReducerProtocol<State, Action> {
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

      if #available(iOS 9999.0, *) {
        Unavailable()
      }
    }
  #else
    var body: Reduce<State, Action> {
      self.core
        .ifLet(\.optionalFeature, action: /Action.optionalFeature) {
          Feature()
          Feature()
        }
        .ifLet(\.enumFeature, action: /Action.enumFeature) {
          EmptyReducer()
            .ifCaseLet(/Features.State.featureA, action: /Features.Action.featureA) {
              Feature()
            }
            .ifCaseLet(/Features.State.featureB, action: /Features.Action.featureB) {
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
    var core: Reduce<State, Action> {
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
    }

    @ReducerBuilder<State, Action>
    var testFlowControl: Reduce<State, Action> {
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

      if #available(iOS 9999.0, *) {
        Unavailable()
      }
    }
  #endif

  struct Feature: ReducerProtocol {
    struct State: Identifiable {
      let id: Int
    }
    enum Action {
      case action
    }

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
      .none
    }
  }

  struct Features: ReducerProtocol {
    enum State {
      case featureA(Feature.State)
      case featureB(Feature.State)
    }

    enum Action {
      case featureA(Feature.Action)
      case featureB(Feature.Action)
    }

    #if swift(>=5.7)
      var body: some ReducerProtocol<State, Action> {
        Scope(state: /State.featureA, action: /Action.featureA) {
          Feature()
        }
        Scope(state: /State.featureB, action: /Action.featureB) {
          Feature()
        }
      }
    #else
      var body: Reduce<State, Action> {
        Scope(state: /State.featureA, action: /Action.featureA) {
          Feature()
        }
        Scope(state: /State.featureB, action: /Action.featureB) {
          Feature()
        }
      }
    #endif
  }
}

private struct IfLetExample: ReducerProtocol {
  struct State {
    var optional: Int?
  }

  enum Action {}

  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      EmptyReducer().ifLet(\.optional, action: .self) { EmptyReducer() }
    }
  #else
    var body: Reduce<State, Action> {
      EmptyReducer().ifLet(\.optional, action: .self) { EmptyReducer() }
    }
  #endif
}

private struct IfCaseLetExample: ReducerProtocol {
  enum State {
    case value(Int)
  }

  enum Action {}

  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      EmptyReducer().ifCaseLet(/State.value, action: .self) { EmptyReducer() }
    }
  #else
    var body: Reduce<State, Action> {
      EmptyReducer().ifCaseLet(/State.value, action: .self) { EmptyReducer() }
    }
  #endif
}

private struct ForEachExample: ReducerProtocol {
  struct Element: Identifiable { let id: Int }

  struct State {
    var values: IdentifiedArrayOf<Element>
  }

  enum Action {
    case value(id: Element.ID, action: Never)
  }

  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      EmptyReducer().forEach(\.values, action: /Action.value) { EmptyReducer() }
    }
  #else
    var body: Reduce<State, Action> {
      EmptyReducer().forEach(\.values, action: /Action.value) { EmptyReducer() }
    }
  #endif
}

private struct ScopeIfLetExample: ReducerProtocol {
  struct State {
    var optionalSelf: Self? {
      get { self }
      set { newValue.map { self = $0 } }
    }
  }

  enum Action {}

  #if swift(>=5.7)
    var body: some ReducerProtocol<State, Action> {
      Scope(state: \.self, action: .self) {
        EmptyReducer()
          .ifLet(\.optionalSelf, action: .self) {
            EmptyReducer()
          }
      }
    }
  #else
    var body: Reduce<State, Action> {
      Scope(state: \.self, action: .self) {
        EmptyReducer()
          .ifLet(\.optionalSelf, action: .self) {
            EmptyReducer()
          }
      }
    }
  #endif
}
