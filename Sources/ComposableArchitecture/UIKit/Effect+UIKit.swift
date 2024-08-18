#if canImport(UIKit) && !os(watchOS)
  import UIKitNavigation

  extension Send {
    /// Sends an action back into the system from an effect with animation.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - animation: An animation.
    public func callAsFunction(_ action: Action, uiKitAnimation: UIKitAnimation?) {
      callAsFunction(action, transaction: UITransaction(animation: uiKitAnimation))
    }
    
    /// Sends an action back into the system from an effect with transaction.
    ///
    /// - Parameters:
    ///   - action: An action.
    ///   - transaction: A transaction.
    public func callAsFunction(_ action: Action, transaction: UITransaction) {
      guard !Task.isCancelled else { return }
      withUITransaction(transaction) {
        self(action)
      }
    }
  }
#endif
