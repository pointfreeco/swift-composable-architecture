import SwiftUI

/// Defines the actions that can be sent from a view.
///
/// See the ``ViewAction(for:)`` macro for more information on how to use this.
public protocol ViewAction<ViewAction> {
  associatedtype ViewAction
  static func view(_ action: ViewAction) -> Self
}

/// A type that represents a view with a ``Store`` that can send ``ViewAction``s.
public protocol ViewActionSending<StoreState, StoreAction> {
  associatedtype StoreState
  associatedtype StoreAction: ViewAction
  @MainActor(unsafe) var store: Store<StoreState, StoreAction> { get }
}

extension ViewActionSending {
  /// Send a view action to the store.
  @discardableResult
  public func send(_ action: StoreAction.ViewAction) -> StoreTask {
    self.store.send(.view(action))
  }

  /// Send a view action to the store with animation.
  @discardableResult
  public func send(_ action: StoreAction.ViewAction, animation: Animation?) -> StoreTask {
    self.store.send(.view(action), animation: animation)
  }

  /// Send a view action to the store with a transaction.
  @discardableResult
  public func send(_ action: StoreAction.ViewAction, transaction: Transaction) -> StoreTask {
    self.store.send(.view(action), transaction: transaction)
  }
}
