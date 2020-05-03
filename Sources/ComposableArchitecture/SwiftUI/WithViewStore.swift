import Combine
import SwiftUI

/// A structure that transforms a store into an observable view store in order to compute views from
/// store state.
///
/// Due to a bug in SwiftUI, there are times that use of this view can interfere with some core
/// views provided by SwiftUI. The known problematic views are:
///
/// * If a `GeometryReader` is used inside a `WithViewStore` it will not receive state updates
///   correctly. To work around you either need to reorder the views so that `GeometryReader`
///   wraps the `WithViewStore`, or, if that is not possible, then you must hold onto an explicit
///   `@ObservedObject var viewStore: ViewStore<State, Action>` in your view in lieu of using
///   this helper (see [here](https://gist.github.com/mbrandonw/cc5da3d487bcf7c4f21c27019a440d18)).
/// * If you create a `Stepper` via the `Stepper.init(onIncrement:onDecrement:label:)` initializer
///   inside a `WithViewStore` it will behave erratically. To work around you should use the
///   initializer that takes a binding (see
///   [here](https://gist.github.com/mbrandonw/dee2ceac2c316a1619cfdf1dc7945f66)).
public struct WithViewStore<State, Action, Content>: View where Content: View {
  private let content: (ViewStore<State, Action>) -> Content
  private var prefix: String?
  @ObservedObject private var viewStore: ViewStore<State, Action>

  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from store state.

  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed,
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.content = content
    self.viewStore = ViewStore(store, removeDuplicates: isDuplicate)
  }

  public var body: some View {
    if let prefix = self.prefix {
      print(
        """
        \(prefix.isEmpty ? "" : "\(prefix): ")\
        Evaluating WithViewStore<\(State.self), \(Action.self), ...>.body
        """
      )
    }
    return self.content(self.viewStore)
  }

  /// Prints debug information to the console whenever the view is computed.
  ///
  /// - Parameter prefix: A string with which to prefix all debug messages.
  /// - Returns: A structure that prints debug messages for all computations.
  public func debug(prefix: String = "") -> Self {
    var view = self
    view.prefix = prefix
    return view
  }
}

extension WithViewStore where State: Equatable {
  /// Initializes a structure that transforms a store into an observable view store in order to
  /// compute views from equatable store state.
  ///
  /// - Parameters:
  ///   - store: A store of equatable state.
  ///   - content: A function that can generate content from a view store.
  public init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content)
  }
}

extension WithViewStore: DynamicViewContent where State: Collection, Content: DynamicViewContent {
  public typealias Data = State

  public var data: State {
    self.viewStore.state
  }
}
