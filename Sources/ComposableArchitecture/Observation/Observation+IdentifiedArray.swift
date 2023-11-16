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

extension Binding {
  /// Scopes the binding of a store to an identified array of child state and actions.
  ///
  /// TODO: Example
  ///
  /// - Parameters:
  ///   - state: A key path to an identified array of child state.
  ///   - action: A case key path to an identified child action.
  /// - Returns: An binding of an array of stores of child state.
  @_disfavoredOverload
  public func scope<State, Action, ElementID, ElementState, ElementAction>(
    state: KeyPath<State, IdentifiedArray<ElementID, ElementState>>,
    action: CaseKeyPath<Action, IdentifiedAction<ElementID, ElementAction>>
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
    store: Store<IdentifiedArray<ElementID, State>, IdentifiedAction<ElementID, Action>>
  )
  where Element == Store<State, Action> {
    self = store.withState(\.ids).map { id in
      store.scope(
        state: { $0[id: id]! },
        id: { _ in id },
        action: { .element(id: id, action: $0) },
        isInvalid: { !$0.ids.contains(id) },
        removeDuplicates: nil
      )
    }
  }
}
