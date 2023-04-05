import OrderedCollections
import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Content: View, Destination: View>: View {
  let content: Content
  let destination: (StackElementID) -> IfLetStore<State, Action, Destination?>
  let store: Store<StackState<State>, StackAction<Action>>
  @StateObject var viewStore: ViewStore<OrderedSet<StackElementID>, StackAction<Action>>

  public init(
    _ store: Store<StackState<State>, StackAction<Action>>,
    @ViewBuilder content: () -> Content,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  ) {
    self.content = content()
    self.destination = { id in
      IfLetStore(
        store.scope(
          state: returningLastNonNilValue { $0[id: id] },
          action: { .element(id: id, action: $0) }
        ),
        then: destination
      )
    }
    self.store = store
    self._viewStore = StateObject(
      wrappedValue: ViewStore(
        store.scope(state: { $0._ids }),
        removeDuplicates: areOrderedSetsDuplicates
      )
    )
  }

  public var body: some View {
    // TODO: Does this binding need to be safer to avoid unsafely subscripting into the stack?
    NavigationStack(
      // TODO: Better binding
      path: Binding(
        get: { self.viewStore.state.elements },
        set: { newIDs in
          if self.viewStore.state.count > newIDs.count {
            self.viewStore.send(.popFrom(id: self.viewStore.state[newIDs.count]))
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
      observe: { $0._ids },
      removeDuplicates: areOrderedSetsDuplicates
    ) { viewStore in
      ForEach(viewStore.state, id: \.self) { id in
        var element = self.store.state.value[id: id]!
        self.content(
          self.store.scope(
            state: {
              element = $0[id: id] ?? element
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
