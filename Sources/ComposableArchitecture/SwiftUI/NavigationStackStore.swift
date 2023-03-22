import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Content: View, Destination: View>: View {
  let content: Content
  let destination: (StackElementID) -> IfLetStore<State, Action, Destination?>
  let store: Store<StackState<State>, StackAction<Action>>

  public init(
    _ store: Store<StackState<State>, StackAction<Action>>,
    @ViewBuilder content: () -> Content,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  ) {
    self.content = content()
    self.destination = { id in
      IfLetStore(
        store.scope(
          state: returningLastNonNilValue { $0[_id: id] },
          action: { .element(id: id, action: $0) }
        ),
        then: destination
      )
    }
    self.store = store
  }

  public var body: some View {
    WithViewStore(
      self.store.scope(
        state: { $0.ids },
        action: StackAction.popFrom(id:)
      )
    ) { viewStore in
      // TODO: Does this binding need to be safer to avoid unsafely subscripting into the stack?
      NavigationStack(
//        path: viewStore.binding(get: { $0 }, send: { viewStore.state[$0.count] })
        path: Binding(
          get: { viewStore.state },
          set: { newIDs in
            if viewStore.state.count > newIDs.count {
              viewStore.send(viewStore.state[newIDs.count])
            }
          }
        )
      ) {
        self.content
          .navigationDestination(for: StackElementID.self) { id in
            self.destination(id)
          }
      }
    }
  }
}

public struct _ForEachStore<State, Action, Content: View>: DynamicViewContent {
  let store: Store<StackState<State>, StackAction<Action>>
  let content: (Store<State, Action>) -> Content

  public init(
    _ store: Store<StackState<State>, StackAction<Action>>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) {
    self.store = store
    self.content = content
  }

  public var body: some View {
    WithViewStore(
      self.store,
      observe: { $0.ids },
      removeDuplicates: memcmpIsEqual
    ) { viewStore in
      ForEach(viewStore.state, id: \.self) { id in
        var element = self.store.state.value[id: id]
        self.content(
          self.store.scope(
            state: {
              element = $0[_id: id] ?? element
              return element
            },
            action: { .element(id: id, action: $0) }
          )
        )
      }
    }
  }

  public var data: StackState<State> {
    self.store.state.value
  }
}
