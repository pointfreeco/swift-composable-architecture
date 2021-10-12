import SwiftUI

/// A view that safely unwraps a store of optional state in order to show one of two views.
///
/// When the underlying state is non-`nil`, the `then` closure will be performed with a ``Store``
/// that holds onto non-optional state, and otherwise the `else` closure will be performed.
///
/// This is useful for deciding between two views to show depending on an optional piece of state:
///
/// ```swift
/// IfLetStore(
///   store.scope(state: \SearchState.results, action: SearchAction.results),
///   then: SearchResultsView.init(store:),
///   else: { Text("Loading search results...") }
/// )
/// ```
///
/// And for performing navigation when a piece of state becomes non-`nil`:
///
/// ```swift
/// NavigationLink(
///   destination: IfLetStore(
///     self.store.scope(state: \.detail, action: AppAction.detail),
///     then: DetailView.init(store:)
///   ),
///   isActive: viewStore.binding(
///     get: \.isGameActive,
///     send: { $0 ? .startButtonTapped : .detailDismissed }
///   )
/// ) {
///   Text("Start!")
/// }
/// ```
///
/// > Note: ``IfLetStore`` will ignore actions sent from the view when its state is `nil`.
public struct IfLetStore<State, Action, Content>: View where Content: View {
  private let content: (ViewStore<State?, Action>) -> Content
  private let store: Store<State?, Action>

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of optional
  /// state is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  ///   - elseContent: A view that is only visible when the optional state is `nil`.
  public init<IfContent, ElseContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    self.store = store
    self.content = { viewStore in
      if var state = viewStore.state {
        return ViewBuilder.buildEither(
          first: ifContent(
            store.scope {
              state = $0 ?? state
              return state
            }
          )
        )
      } else {
        return ViewBuilder.buildEither(second: elseContent())
      }
    }
  }

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of optional
  /// state is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  public init<IfContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (Store<State, Action>) -> IfContent
  ) where Content == IfContent? {
    self.store = store
    self.content = { viewStore in
      if var state = viewStore.state {
        return ifContent(
          store
            .scope(
              state: { $0 },
              action: { $0 },
              send: { state, action, send in
                if state != nil {
                  send(action)
                } else {
                  print("""
                    An "IfLetStore" view sent the action \(debugCaseOutput(action)) when its state \
                    was "nil". SwiftUI may have written to a binding after the view went away. If \
                    you sent an action from ".onDisappear" then you must handle that action in the
                    parent domain.
                    """)
                }
              }
            )
            .scope(
              state: {
                state = $0 ?? state
                return state
              }
            )
        )
      } else {
        return nil
      }
    }
  }

  public var body: some View {
    WithViewStore(
      self.store,
      removeDuplicates: { ($0 != nil) == ($1 != nil) },
      content: self.content
    )
  }
}
