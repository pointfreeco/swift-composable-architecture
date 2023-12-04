import SwiftUI

/// Defines the actions that can be sent from a view.
///
/// See the ``ViewAction(for:)`` macro for more information on how to use this.
public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
}

public protocol ViewActionable<State, Action> {
  associatedtype State
  associatedtype Action: ViewAction
  var store: Store<State, Action> { get }
}

extension ViewActionable {
  @discardableResult
  public func send(_ action: Action.ViewAction) -> StoreTask {
    self.store.send(.view(action))
  }
  @discardableResult
  public func send(_ action: Action.ViewAction, animation: Animation?) -> StoreTask {
    self.store.send(.view(action), animation: animation)
  }
  @discardableResult
  public func send(_ action: Action.ViewAction, transaction: Transaction) -> StoreTask {
    self.store.send(.view(action), transaction: transaction)
  }
}
