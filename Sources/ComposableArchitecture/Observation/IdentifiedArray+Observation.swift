import SwiftUI

extension Store {
  /// Scopes the store to an identified array of child state and actions.
  ///
  /// TODO: Example
  ///
  /// - Parameters:
  ///   - state: A key path to an identified array of child state.
  ///   - action: A case key path to an identified child action.
  /// - Returns: An array of stores of child state.
  @_disfavoredOverload
  public func scope<ElementID, ElementState, ElementAction>(
    state: KeyPath<State, IdentifiedArray<ElementID, ElementState>>,
    action: CaseKeyPath<Action, IdentifiedAction<ElementID, ElementAction>>
  ) -> [Store<ElementState, ElementAction>] {
    Array(store: self.scope(state: state, action: action))
  }
}

fileprivate extension Array {
  init<ElementID: Hashable, State, Action>(
    store: Store<IdentifiedArray<ElementID, State>, IdentifiedAction<ElementID, Action>>
  )
  where Element == Store<State, Action> {
    self = store.withState(\.ids).map { id in
      store.scope(
        state: { $0[id: id]! },
        id: ScopeID(
          state: \IdentifiedArray<ElementID, State>.[id: id],
          action: \IdentifiedAction<ElementID, Action>.Cases[id: id]
        ),
        action: { .element(id: id, action: $0) },
        isInvalid: { !$0.ids.contains(id) },
        removeDuplicates: nil
      )
    }
  }
}
