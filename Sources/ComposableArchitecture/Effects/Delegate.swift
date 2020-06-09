import Combine
import Foundation

/// Whenever you're trying to fit an existing delegate protocol into the Combosable Architecture, you can opt to conform it to this protocol as well.
/// When you do, for every delegate method you need to hook up to the architecture, just call `subscriber?.send()`
///  with the action you need to pass into your store.
///
/// For instance, if you need to implement UISearchBarDelegate and pass its calls into your store, you can do this:
///
/// ```
/// enum MySearchAction {
///   case textDidChange(String)
///   // etc...
/// }
///
/// class SearchBarDelegate: NSObject, UISearchBarDelegate, EffectDelegate {
///   var subscriber: Effect<MySearchAction, Never>.Subscriber?
///
///   func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
///     subscriber?.send(.textDidChange(searchText))
///   }
///
///   // etc...
/// }
/// ```

protocol EffectDelegate: AnyObject {
  associatedtype Output
  associatedtype Failure: Error

  var subscriber: Effect<Output, Failure>.Subscriber? { get set }
}

extension Effect {

  /// Creates an effect from the given `EffectDelegate`, which (given that the `EffectDelegate` implementation is written correctly) will emit values whenever the delegate's methods are called.
  ///
  /// - Parameters:
  ///   - delegate: The delegate to build an effect from.
  ///   - onCancel: An optional closure to provide any cleanup behavior you wish when the effect is cancelled.
  /// - Returns: A new `Effect` that will send values for any of the given delegate's callbacks.
  static func from<Delegate: EffectDelegate>(
    delegate: Delegate,
    onCancel: () -> Void = {}
  ) -> Effect<Output, Failure>
    where Delegate.Output == Effect.Output, Delegate.Failure == Effect.Failure
  {
    Effect.run { subscriber in
      delegate.subscriber = subscriber
      return AnyCancellable {
        delegate.subscriber = nil
        onCancel()
      }
    }
  }
}
