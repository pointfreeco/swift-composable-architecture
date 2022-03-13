import Combine

extension Effect {
  public init(@EffectBuilder effects: (Self.Type) -> Self) {
    self = effects(Self.self)
  }
  public init(@EffectBuilder effects: () -> Self) {
    self = effects()
  }
}

extension Effect {
  @resultBuilder
  public enum EffectBuilder {

    public static func buildExpression(_ expression: Void) -> Effect {
      .none
    }

    public static func buildExpression(_ expression: Output) -> Effect {
      Effect(value: expression)
    }

    public static func buildExpression(_ expression: Failure) -> Effect {
      Effect(error: expression)
    }

    public static func buildExpression(_ expression: Effect) -> Effect {
      expression
    }

    public static func buildBlock(_ components: Effect...) -> Effect {
      .merge(components)
    }

    public static func buildOptional(_ component: Effect?) -> Effect {
      component ?? .none
    }

    public static func buildEither(first component: Effect) -> Effect {
      component
    }

    public static func buildEither(second component: Effect) -> Effect {
      component
    }

    public static func buildArray(_ components: [Effect]) -> Effect {
      .merge(components)
    }

    public static func buildLimitedAvailability(_ component: Effect) -> Effect {
      component
    }
  }
}

//---

private enum Action {
  case action1
  case action2
}

private let reducer = Reducer<Void, Action, Void>.init { _, _, _ in
  Effect {
    .action1
    //    $0.init(value: .action2)
    //      .delay(for: .seconds(3), scheduler: DispatchQueue.main.eraseToAnyScheduler())
    //      .eraseToEffect()
    $0.fireAndForget {

    }
    if 4.isZero {
      .action2
    }
    $0.none
    Effect {
      Action.action2
      Action.action1
    }

    $0.future({ _ in

    })

    Effect {

    }

    $0.fireAndForget {

    }

    Effect.FFuture { _ in }.effect
  }
}

public protocol EffectDeclarating {
  associatedtype Output
  associatedtype Failure where Failure: Error
  var effect: Effect<Output, Failure> { get }
}

extension Effect {
  public struct FFuture: EffectDeclarating {
    public init(attemptToFulfill: @escaping (@escaping (Result<Output, Failure>) -> Void) -> Void) {
      self.effect = .future(attemptToFulfill)
    }
    public let effect: Effect<Output, Failure>
  }
}

//public static func future(
//  _ attemptToFulfill: @escaping (@escaping (Result<Output, Failure>) -> Void) -> Void
//) -> Effect {
//  Deferred { Future(attemptToFulfill) }.eraseToEffect()
//}
