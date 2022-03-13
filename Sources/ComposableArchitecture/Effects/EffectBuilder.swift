import Combine

extension Effect {
  public init(@Builder effects: (Self.Type) -> Self) {
    self = effects(Self.self)
  }
  
  public init(@Builder effects: () -> Self) {
    self = effects()
  }
  
  var isNotNone: Bool { !isNone }
}

extension Effect {
  @resultBuilder
  public enum Builder {
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
      .merge(components.filter(\.isNotNone))
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
      .merge(components.filter(\.isNotNone))
    }

    public static func buildLimitedAvailability(_ component: Effect) -> Effect {
      component
    }
  }
}
