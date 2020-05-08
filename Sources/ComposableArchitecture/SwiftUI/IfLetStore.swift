import SwiftUI

/// A view that safely unwraps a store of optional state in order to show one of two views.
/// When the underlying state is non-`nil`, the `then` closure will be performed with a `Store`
/// that holds onto non-optional state, and otherwise the `else` closure will be performed.
///
/// This is useful for deciding between two views to show depending on an optional piece of state:
///
///     IfLetStore(
///       store.scope(state: \SearchState.results, action: SearchAction.results),
///       then: SearchResultsView.init(store:),
///       else: Text("Loading search results...")
///     )
///
///  And for performing navigation when a piece of state becomes non-`nil`:
///
///      NavigationLink(
///        destination: IfLetStore(
///          self.store.scope(state: \.detail, action: AppAction.detail),
///          then: DetailView.init(store:)
///        ),
///        isActive: viewStore.binding(
///          get: \.isGameActive,
///          send: { $0 ? .startButtonTapped : .detailDisissed }
///        )
///      ) {
///        Text("Start!")
///      }
///
public struct IfLetStore<State, Action, IfContent, ElseContent>: View
where IfContent: View, ElseContent: View {
  public let store: Store<State?, Action>
  public let ifContent: (Store<State, Action>) -> IfContent
  public let elseContent: () -> ElseContent

  /// Initializes an `IfLetStore` view when you have views you want to show for the case that state
  /// is non-`nil` _and_ the case that it is `nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  ///   - elseContent: A view that is only visible when the optional state is `nil`.
  public init(
    _ store: Store<State?, Action>,
    then ifContent: @escaping (Store<State, Action>) -> IfContent,
    else elseContent: @escaping @autoclosure () -> ElseContent
  ) {
    self.store = store
    self.ifContent = ifContent
    self.elseContent = elseContent
  }

  public var body: some View {
    WithViewStore(
      self.store,
      removeDuplicates: { ($0 != nil) == ($1 != nil) }
    ) { viewStore -> _ConditionalContent<IfContent, ElseContent> in
      if let state = viewStore.state {
        return
          ViewBuilder.buildEither(first: self.ifContent(self.store.scope(state: { $0 ?? state })))
          as _ConditionalContent<IfContent, ElseContent>
      } else {
        return
          ViewBuilder.buildEither(second: self.elseContent())
          as _ConditionalContent<IfContent, ElseContent>
      }
    }
  }
}

extension IfLetStore where ElseContent == EmptyView {
  /// An overload of `IfLetStore.init(_:then:else:)` that does not take the `else` argument and
  /// instead uses an `EmptyView`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  public init(
    _ store: Store<State?, Action>,
    then ifContent: @escaping (Store<State, Action>) -> IfContent
  ) {
    self.init(store, then: ifContent, else: EmptyView())
  }
}
