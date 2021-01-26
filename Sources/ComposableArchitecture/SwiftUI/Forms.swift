import CasePaths
import SwiftUI

/// An action that describes a simple mutations to state with a writable key path.
public struct FormAction<Root> {
  public let keyPath: PartialKeyPath<Root>
  
  private let isEqualTo: ((Any) -> Bool)?
  fileprivate let set: (inout Root) -> Void
  private let value: Any

  public static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self {
    .init(
      keyPath: keyPath,
      isEqualTo: nil,
      set: { $0[keyPath: keyPath] = value },
      value: value
    )
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
      isEqualTo: self.isEqualTo,
      set: { self.set(&$0[keyPath: keyPath]) },
      value: self.value
    )
  }
}

extension FormAction: Equatable {
  public static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self
  where Value: Equatable {
    .init(
      keyPath: keyPath,
      isEqualTo: { value == $0 as? Value },
      set: { $0[keyPath: keyPath] = value },
      value: value
    )
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.isEqualTo?(rhs.value) == .some(true)
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
  ) -> Binding<LocalState> {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.set(keyPath, $0)) }
    )
  }

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
