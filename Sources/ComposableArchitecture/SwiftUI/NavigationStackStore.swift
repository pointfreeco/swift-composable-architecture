import OrderedCollections
import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Content: View, Destination: View>: View {
  let content: Content
  let destination: (StackElementID) -> IfLetStore<State, Action, Destination?>
  @StateObject private var viewStore: ViewStore<StackState<State>, StackAction<State, Action>>

  public init(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
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
    self._viewStore = StateObject(
      wrappedValue: ViewStore(
        store,
        removeDuplicates: { areOrderedSetsDuplicates($0._ids, $1._ids) }
      )
    )
  }

  public var body: some View {
    // TODO: Does this binding need to be safer to avoid unsafely subscripting into the stack?
    NavigationStack(
      path: self.viewStore.binding(get: { $0.path }, send: { .setPath($0.base) })
    ) {
      self.content
        .navigationDestination(for: Component<State>.self) { component in
          self.destination(component.id)
        }
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  public init<P: Hashable>(state: P?, label: () -> Label) {
    @Dependency(\.stackElementID) var stackElementID
    self.init(value: state.map { Component(id: stackElementID(), element: $0) }, label: label)
  }

  public init<P: Hashable>(_ titleKey: LocalizedStringKey, state: P?) where Label == Text {
    @Dependency(\.stackElementID) var stackElementID
    self.init(titleKey, value: state.map { Component(id: stackElementID(), element: $0) })
  }

  @_disfavoredOverload
  public init<S: StringProtocol, P: Hashable>(_ title: S, state: P?) where Label == Text {
    @Dependency(\.stackElementID) var stackElementID
    self.init(title, value: state.map { Component(id: stackElementID(), element: $0) })
  }
}

public struct _ForEachStore<State, Action, Content: View>: DynamicViewContent {
  let store: Store<StackState<State>, StackAction<State, Action>>
  let content: (Store<State, Action>) -> Content

  public init(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
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
