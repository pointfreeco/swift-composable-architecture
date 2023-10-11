import SwiftUI

@available(iOS 17, tvOS 17, watchOS 10, macOS 14, *)
extension NavigationStack {
  public init<State: ObservableState, Action, Destination, R>(
    store: Store<StackState<State>, StackAction<State, Action>>,
    root: () -> R,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  )
  where
    Data == StackState<State>.PathView,
    Destination: View,
    Root == ModifiedContent<R, _NavigationDestinationViewModifier<State, Action, Destination>>
  {
    self.init(
      path: Binding(
        get: { store.observedState.path },
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

@available(iOS 17, tvOS 17, watchOS 10, macOS 14, *)
public struct _NavigationDestinationViewModifier<State: ObservableState, Action, Destination: View>:
  ViewModifier
{
  @SwiftUI.State var store: Store<StackState<State>, StackAction<State, Action>>
  fileprivate let destination: (Store<State, Action>) -> Destination

  public func body(content: Content) -> some View {
    content
      .environment(\.navigationDestinationType, State.self)
      .navigationDestination(for: StackState<State>.Component.self) { component in
        if let store = self.store.scope(
          state: \.[id: component.id],
          action: { .element(id: component.id, action: $0) }
        ) {
          self
            .destination(store)
            .environment(\.navigationDestinationType, State.self)
        }
      }
  }
}
