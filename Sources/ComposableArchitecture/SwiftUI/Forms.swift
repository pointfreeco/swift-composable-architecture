import CasePaths
import SwiftUI

/// An action that describes a simple mutations to state with a writable key path.
public struct FormAction<Root>: Equatable {
  public let keyPath: PartialKeyPath<Root>
  
  fileprivate let set: (inout Root) -> Void
  private let value: Any
  private let valueIsEqualTo: (Any) -> Bool

  public static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self
  where Value: Equatable {
    .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath] = value },
      value: value,
      valueIsEqualTo: { $0 as? Value == value }
    )
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
  }

  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, Value>,
    formAction: FormAction<Root>
  ) -> Bool {
    keyPath == formAction.keyPath
  }

  public func pullback<NewRoot>(_ keyPath: WritableKeyPath<NewRoot, Root>) -> FormAction<NewRoot> {
    .init(
      keyPath: (keyPath as AnyKeyPath).appending(path: self.keyPath) as! PartialKeyPath<NewRoot>,
      set: { self.set(&$0[keyPath: keyPath]) },
      value: self.value,
      valueIsEqualTo: self.valueIsEqualTo
    )
  }
}

extension Reducer {
  public func form(action toFormAction: CasePath<Action, FormAction<State>>) -> Self {
    Self { state, action, environment in
      toFormAction.extract(from: action)?.set(&state)
      return .none
    }
    .combined(with: self)
  }
}

extension ViewStore {
  public func binding<LocalState>(
    keyPath: WritableKeyPath<State, LocalState>,
    send action: @escaping (FormAction<State>) -> Action
  ) -> Binding<LocalState>
  where LocalState: Equatable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.set(keyPath, $0)) }
    )
  }
}
