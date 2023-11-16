import Perception
import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationStack {
  // TODO: Should we somehow enforce observability of the parent state?
  //   * Could require a binding of a store, instead, and constrain that interface.
  //     ```
  //     NavigationStack(path: $store.scope(state: \.path, action: \.path)) { … }
  //     ```
  //   * ```
  //     NavigationStack(store: store, state: \.path, action: \.path) { … }
  //     ```
  //   * ```
  //     protocol NavigableState: ObservableState {
  //       associatedtype PathState
  //       var path: StackState<PathState>
  //     }
  //     protocol NavigableAction {
  //       associatedtype PathState
  //       associatedtype PathAction
  //
  //       static func path(_: StackAction<PathState, PathAction>) -> Self
  //       var path: StackAction<PathState, PathAction>?
  //       // (Or somehow abstract over a case-pathable case key path.)
  //     }
  //
  //     // Necessary?
  //     protocol NavigableReducer: Reducer {
  //       associatedtype State: NavigableState
  //       associatedtype Action: NavigableAction
  //     }
  //     ...
  //     NavigationStack(store: store) { … }
  //     ```

  /// Drives a navigation stack with a store.
  ///
  /// > Warning: The feature state containing ``StackState`` must be annotated with
  /// > ``ObservableObject`` for navigation to be observed.
  ///
  /// See the dedicated article on <doc:Navigation> for more information on the library's navigation
  /// tools, and in particular see <doc:StackBasedNavigation> for information on using this view.
  public init<State, Action, Destination: View, R>(
    store: Store<StackState<State>, StackAction<State, Action>>,
    root: () -> R,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  )
  where
    Data == StackState<State>.PathView,
    Root == ModifiedContent<R, _NavigationDestinationViewModifier<State, Action, Destination>>
  {
    self.init(
      path: Binding(
        get: { store.observableState.path },
        set: { pathView in
          if pathView.count > store.withState({ $0 }).count, let component = pathView.last {
            store.send(.push(id: component.id, state: component.element))
          } else {
            store.send(.popFrom(id: store.withState { $0 }.ids[pathView.count]))
          }
        }
      )
    ) {
      root()
        .modifier(_NavigationDestinationViewModifier(store: store, destination: destination))
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct _NavigationDestinationViewModifier<
  State: ObservableState, Action, Destination: View
>:
  ViewModifier
{
  @SwiftUI.State var store: Store<StackState<State>, StackAction<State, Action>>
  fileprivate let destination: (Store<State, Action>) -> Destination

  public func body(content: Content) -> some View {
    content
      .environment(\.navigationDestinationType, State.self)
      .navigationDestination(for: StackState<State>.Component.self) { component in
        var state = component.element
        WithPerceptionTracking {
          self
            .destination(
              self.store.scope(
                state: {
                  state = $0[id: component.id] ?? state
                  return state
                },
                id: { _ in component.id },
                action: { .element(id: component.id, action: $0) },
                isInvalid: { !$0.ids.contains(component.id) },
                removeDuplicates: nil
              )
            )
            .environment(\.navigationDestinationType, State.self)
        }
      }
  }
}
