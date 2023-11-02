import SwiftUI

extension ForEach {
  public init<ElementID: Hashable, State, Action>(
    store: Store<IdentifiedArray<ElementID, State>, (id: ElementID, action: Action)>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content
  ) where Data == [Store<State, Action>], ID == ObjectIdentifier, Content: View {
    self.init(Array(store: store), content: content)
  }

  public init<ElementID: Hashable, State, Action>(
    store: Binding<Store<IdentifiedArray<ElementID, State>, (id: ElementID, action: Action)>>,
    @ViewBuilder content: @escaping (Binding<Store<State, Action>>) -> Content
  )
  where
    Data == LazyMapSequence<
      [Store<State, Action>].Indices,
      (Array<Store<State, Action>>.Index, ObjectIdentifier)
    >,
    ID == ObjectIdentifier,
    Content: View
  {
    self.init(
      Binding(
        get: { Array(store: store.wrappedValue) },
        set: { _, _ in }
      ),
      content: content
    )
  }
}

fileprivate extension Array {
  init<ElementID: Hashable, State, Action>(
    store: Store<IdentifiedArray<ElementID, State>, (id: ElementID, action: Action)>
  )
  where Element == Store<State, Action> {
    self = store.withState(\.ids).map { id in
      store.scope(
        state: { $0[id: id]! },
        id: { _ in id },
        action: { (id: id, action: $1) },
        isInvalid: { !$0.ids.contains(id) },
        removeDuplicates: nil
      )
    }
  }
}
