import Perception
import SwiftUI

extension Binding {
  // TODO: Document
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    let isInViewBody = PerceptionLocals.isInPerceptionTracking
    return Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>(
      get: {
        // TODO: Can this be localized to the `Perception` framework?
        PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
          self.wrappedValue.scope(state: state, action: action)
        }
      },
      set: { _ in }
    )
  }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Bindable {
  // TODO: Document
  public func scope<State: ObservableState, Action, ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>
  where Value == Store<State, Action> {
    Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>(
      get: { self.wrappedValue.scope(state: state, action: action) },
      set: { _ in }
    )
  }
}

extension BindableStore {
  // TODO: Document
  public func scope<ElementState, ElementAction>(
    state: KeyPath<State, StackState<ElementState>>,
    action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>
  ) -> Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>> {
    Binding<Store<StackState<ElementState>, StackAction<ElementState, ElementAction>>>(
      get: { self.wrappedValue.scope(state: state, action: action) },
      set: { _ in }
    )
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationStack {
  /// Drives a navigation stack with a store.
  ///
  /// > Warning: The feature state containing ``StackState`` must be annotated with
  /// > ``ObservableObject`` for navigation to be observed.
  ///
  /// See the dedicated article on <doc:Navigation> for more information on the library's navigation
  /// tools, and in particular see <doc:StackBasedNavigation> for information on using this view.
  public init<State, Action, Destination: View, R>(
    path: Binding<Store<StackState<State>, StackAction<State, Action>>>,
    root: () -> R,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  )
  where
    Data == StackState<State>.PathView,
    Root == ModifiedContent<R, _NavigationDestinationViewModifier<State, Action, Destination>>
  {
    self.init(
      path: Binding(
        get: { path.wrappedValue.observableState.path },
        set: { pathView, transaction in
          if pathView.count > path.wrappedValue.withState({ $0 }).count,
            let component = pathView.last
          {
            path.transaction(transaction).wrappedValue.send(
              .push(id: component.id, state: component.element)
            )
          } else {
            path.transaction(transaction).wrappedValue.send(
              .popFrom(id: path.wrappedValue.withState { $0 }.ids[pathView.count])
            )
          }
        }
      )
    ) {
      root()
        .modifier(
          _NavigationDestinationViewModifier(store: path.wrappedValue, destination: destination)
        )
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
                id: ScopeID(
                  state: \StackState<State>.[id: component.id],
                  action: \StackAction<State, Action>.Cases[id: component.id]
                ),
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
