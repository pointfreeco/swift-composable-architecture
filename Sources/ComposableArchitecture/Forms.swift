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

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.value == rhs.value
  }
}

extension Reducer {
  public func form(action: CasePath<Action, FormAction<State>>) -> Self {
    Reducer<State, FormAction<State>, Void> { state, action, _ in
      action.setter(&state)
      return .none
    }
    .pullback(state: \.self, action: action, environment: { _ in () })
    .combined(with: self)
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
