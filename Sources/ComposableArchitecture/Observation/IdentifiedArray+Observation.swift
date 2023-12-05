import OrderedCollections
import SwiftUI

extension Store {
  /// Scopes the store to an identified array of child state and actions.
  ///
  /// TODO: Example
  ///
  /// - Parameters:
  ///   - state: A key path to an identified array of child state.
  ///   - action: A case key path to an identified child action.
  /// - Returns: An collection of stores of child state.
  @_disfavoredOverload
  public func scope<ElementID, ElementState, ElementAction>(
    state: KeyPath<State, IdentifiedArray<ElementID, ElementState>>,
    action: CaseKeyPath<Action, IdentifiedAction<ElementID, ElementAction>>
  ) -> some RandomAccessCollection<Store<ElementState, ElementAction>> {
    #if DEBUG
      if !self.canCacheChildren {
        runtimeWarn(
          """
          Scoping from uncached \(self) is not compatible with observation. Ensure all store \
          scoping operations in your application have been updated to take key paths and case key \
          paths instead of transform functions, which have been deprecated.
          """
        )
      }
    #endif
    return _StoreCollection(self.scope(state: state, action: action))
  }
}

public struct _StoreCollection<ID: Hashable, State, Action>: RandomAccessCollection {
  private let store: Store<IdentifiedArray<ID, State>, IdentifiedAction<ID, Action>>
  // TODO: Should this be an entire snapshot of store state? `IdentifiedArray<ID, State>`?
  // Could return inert stores that warn when sending actions or accessing state without crashing.
  private let ids: OrderedSet<ID>

  fileprivate init(_ store: Store<IdentifiedArray<ID, State>, IdentifiedAction<ID, Action>>) {
    self.store = store
    self.ids = store.withState(\.ids)
  }

  public var startIndex: Int { self.ids.startIndex }
  public var endIndex: Int { self.ids.endIndex }
  public subscript(position: Int) -> Store<State, Action> {
    let id = self.ids[position]
    return self.store.scope(
      state: { $0[id: id]! },
      id: ScopeID(
        state: \IdentifiedArray<ID, State>.[id: id],
        action: \IdentifiedAction<ID, Action>.Cases[id: id]
      ),
      action: { .element(id: id, action: $0) },
      isInvalid: { !$0.ids.contains(id) },
      removeDuplicates: nil
    )
  }
}
