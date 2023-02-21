import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Content: View, Destination: View>: View {
  let content: Content
  let destination: (ElementID) -> IfLetStore<State, Action, Destination?>
  let store: Store<NavigationState<State>.Path, NavigationAction<Action>>

  public init(
    _ store: Store<NavigationState<State>.Path, NavigationAction<Action>>,
    @ViewBuilder content: () -> Content,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  ) {
    self.content = content()
    self.destination = { id in
      IfLetStore(
        store.scope(
          state: returningLastNonNilValue { $0.state._elements[id] },
          action: { .element(id: id, $0) }
        ),
        then: destination
      )
    }
    self.store = store
  }

  public var body: some View {
    WithViewStore(
      self.store.scope(
        state: \.state._ids.elements,
        action: { .pathChanged(ids: $0) }
      )
    ) { viewStore in
      NavigationStack(path: viewStore.binding(get: { $0 }, send: { $0 })) {
        self.content
          .navigationDestination(for: ElementID.self) { id in
            self.destination(id)
          }
      }
    }
  }
}
