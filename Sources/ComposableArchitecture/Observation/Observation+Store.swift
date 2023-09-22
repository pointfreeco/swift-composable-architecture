import Foundation
import SwiftUI

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Store: Observable {
  var observedState: State {
    get {
      self.access(keyPath: \.observedState)
      return self.subject.value
    }
    set {
      if isIdentityEqual(self.subject.value, newValue) {
        self.subject.value = newValue
      } else {
        self.withMutation(keyPath: \.observedState) {
          self.subject.value = newValue
        }
      }
    }
  }

  internal nonisolated func access<Member>(keyPath: KeyPath<Store, Member>) {
    _$observationRegistrar.rawValue.access(self, keyPath: keyPath)
  }

  internal nonisolated func withMutation<Member, T>(
    keyPath: KeyPath<Store, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    try _$observationRegistrar.rawValue.withMutation(of: self, keyPath: keyPath, mutation)
  }
}

@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension Store where State: ObservableState {
  private(set) public var state: State {
    get { self.observedState }
    set { self.observedState = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.state[keyPath: keyPath]
  }
}

extension Store: Equatable {
  public static func == (lhs: Store, rhs: Store) -> Bool {
    lhs === rhs
  }
}

extension Store: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

extension Store: Identifiable {}

// TODO: Constrain?
extension Store {
  public func scope<ChildState, ChildAction>(
    state stateKeyPath: KeyPath<State, ChildState?>,
    action embedChildAction: @escaping (ChildAction) -> Action
  ) -> Store<ChildState, ChildAction>? {
    guard var childState = self.subject.value[keyPath: stateKeyPath]
    else {
      return nil
    }
    return self.scope(
      state: {
        childState = $0[keyPath: stateKeyPath] ?? childState
        return childState
      },
      action: embedChildAction
    )
  }
}
