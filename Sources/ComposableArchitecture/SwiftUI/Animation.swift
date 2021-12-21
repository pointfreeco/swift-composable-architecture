import SwiftUI

extension ViewStore {
  /// Sends an action to the store with a given animation.
  ///
  /// - Parameters:
  ///   - action: An action.
  ///   - animation: An animation.
  public func send(_ action: Action, animation: Animation?) {
    withAnimation(animation) {
      self.send(action)
    }
  }
}

// MARK: Animated Actions

/// A type that wraps an action as an animated action.
public struct AnimatedAction<Action> {
  let action: Action
  let transaction: Transaction
  
  /// Creates an animated action from an action and a animation.
  /// - Parameters:
  ///   - action: an `Action`
  ///   - animation: an `Animation`
  /// - Returns: An action animating `action` with the animation `animation`.
  public static func action(_ action: Action, with animation: Animation) -> Self {
    .init(action: action, transaction: Transaction(animation: animation))
  }
  
  /// Creates an animated action from an action and a transaction.
  /// - Parameters:
  ///   - action: an `Action`
  ///   - transaction: a `Transaction`
  /// - Returns: An action animating `action` with the transaction `transaction`.
  public static func action(_ action: Action, with transaction: Transaction) -> Self {
    .init(action: action, transaction: transaction)
  }
}

extension AnimatedAction: Equatable where Action: Equatable {
  public static func == (lhs: AnimatedAction<Action>, rhs: AnimatedAction<Action>) -> Bool {
    guard
      lhs.action == rhs.action,
      // FIXME: Is this correct?
        lhs.transaction.animation == rhs.transaction.animation,
        lhs.transaction.disablesAnimations == rhs.transaction.disablesAnimations,
        lhs.transaction.isContinuous == rhs.transaction.isContinuous
    else { return false }
    return true
  }
}

/// An action type that exposes a `animated` case that holds an ``AnimatedAction``.
public protocol AnimatableAction {
  /// Embeds an animated action in this action type.
  ///
  ///  - Note: When installed in an `enum`, declare this as:
  /// ```swift
  /// indirect case animated(AnimatedAction<Self>)
  /// ```
  /// - Returns: A animated action.
  static func animated(_ action: AnimatedAction<Self>) -> Self
}

extension AnimatableAction {
  
  /// Wrap an action in an ``AnimatedAction<Self>``
  /// - Parameter animation: The animation to use.
  /// - Returns: A `.animated` version of `self` with the animation `animation`.
  public func animation(_ animation: Animation) -> Self {
    .animated(.action(self, with: animation))
  }
  
  /// Wrap an action in an ``AnimatedAction<Self>``
  /// - Parameter transaction: The transaction to use.
  /// - Returns: A `.animated` version of `self` with the transaction `transaction`.
  public func transaction(_ transaction: Transaction) -> Self {
    .animated(.action(self, with: transaction))
  }
}

#if compiler(>=5.4)
  import Combine
  import CombineSchedulers
  extension Reducer where Action: AnimatableAction {
    /// Returns a reducer that schedules `AnimatedAction.action` onto the provided `Scheduler`'s
    /// animations or transactions.
    ///
    /// The `Action` type should conform to `AnimatableAction`:
    ///
    /// ```swift
    /// enum SettingsAction: AnimatableAction {
    ///   ...
    ///   indirect case animated(AnimatedAction<Self>)
    /// }
    /// ```
    /// - Parameters:
    ///   - scheduler: A function or a `KeyPath` that extracts a `Scheduler` from the environment.
    /// - Returns: A reducer that animates `.animated()` actions.
    public func animations<S>(scheduler: @escaping (Environment) -> S) -> Self where S: Scheduler {
      Self { state, action, environment in
        guard let animatingAction = (/Action.animated).extract(from: action)
        else {
          return self.run(&state, action, environment)
        }
        return Effect(value: animatingAction.action)
          .receive(on: scheduler(environment)
            .eraseToAnyScheduler()
            .transaction(animatingAction.transaction)
          )
          .eraseToEffect()
      }
    }
  }
#endif
