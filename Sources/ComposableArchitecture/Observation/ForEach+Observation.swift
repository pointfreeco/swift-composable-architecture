import SwiftUI

extension Store {
  @_disfavoredOverload
  public func scope<ElementID, ElementState, ElementAction>(
    state: KeyPath<State, IdentifiedArray<ElementID, ElementState>>,
    action: CaseKeyPath<Action, (id: ElementID, action: ElementAction)>
  ) -> [Store<ElementState, ElementAction>] {
    Array(store: self.scope(state: state, action: action))
  }
}

extension Binding {
  @_disfavoredOverload
  public func scope<State, Action, ElementID, ElementState, ElementAction>(
    state: KeyPath<State, IdentifiedArray<ElementID, ElementState>>,
    action: CaseKeyPath<Action, (id: ElementID, action: ElementAction)>
  ) -> Binding<[Store<ElementState, ElementAction>]>
  where Value == Store<State, Action> {
    Binding<[Store<ElementState, ElementAction>]>(
      get: { self.wrappedValue.scope(state: state, action: action) },
      set: { _, _ in }
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
