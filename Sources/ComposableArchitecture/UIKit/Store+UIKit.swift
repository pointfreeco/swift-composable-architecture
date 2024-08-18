#if canImport(UIKit) && !os(watchOS)
  import UIKitNavigation

  extension Store {
    /// Sends an action to the store with a given animation.
    ///
    /// See ``Store/send(_:)`` for more info.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - animation: An animation.
    @discardableResult
    public func send(_ action: Action, uiKitAnimation: UIKitAnimation?) -> StoreTask {
      send(action, transaction: UITransaction(animation: uiKitAnimation))
    }
    
    /// Sends an action to the store with a given transaction.
    ///
    /// See ``Store/send(_:)`` for more info.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - transaction: A transaction.
    @discardableResult
    public func send(_ action: Action, transaction: UITransaction) -> StoreTask {
      withUITransaction(transaction) {
        .init(rawValue: self.send(action, originatingFrom: nil))
      }
    }
  }
#endif
