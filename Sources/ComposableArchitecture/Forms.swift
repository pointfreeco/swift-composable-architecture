import SwiftUI

private struct AnyEquatable: Equatable {
  let isEqualTo: (Any) -> Bool
  let rawValue: Any

  init<Value: Equatable>(_ value: Value) {
    self.isEqualTo = { value == $0 as? Value }
    self.rawValue = value
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.isEqualTo(rhs.rawValue)
  }
}

func ~= <Root, Value>(keyPath: WritableKeyPath<Root, Value>, formAction: FormAction<Root>) -> Bool {
  formAction.keyPath == keyPath
}

public struct FormAction<Root>: Equatable {
  public let keyPath: PartialKeyPath<Root>
  fileprivate let setter: (inout Root) -> Void
  private let value: AnyEquatable

  public init<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) where Value: Equatable {
    self.keyPath = keyPath
    self.value = AnyEquatable(value)
    self.setter = { $0[keyPath: keyPath] = value }
  }

  public static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    to value: Value
  ) -> Self where Value: Equatable {
    Self(keyPath, value)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.value == rhs.value
  }
}

extension Reducer {
  public func form(action formAction: CasePath<Action, FormAction<State>>) -> Self {
    Self { state, action, environment in
      guard let formAction = formAction.extract(from: action)
      else {
        return self.run(&state, action, environment)
      }
      formAction.setter(&state)
      return self.run(&state, action, environment)
    }
  }
}

extension ViewStore {
  public func binding<Value>(
    get keyPath: WritableKeyPath<State, Value>,
    send action: @escaping (FormAction<State>) -> Action
  ) -> Binding<Value> where Value: Equatable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.init(keyPath, $0)) }
    )
  }
}

extension ViewStore where Action == FormAction<State> {
  public func binding<Value>(
    _ keyPath: WritableKeyPath<State, Value>
  ) -> Binding<Value> where Value: Equatable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { .init(keyPath, $0) }
    )
  }
}
