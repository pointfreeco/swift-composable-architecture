import OrderedCollections
import SwiftUI

extension Store where State: ObservableState {
  /// Scopes the store of an identified collection to a collection of stores.
  ///
  /// This operator is most often used with SwiftUI's `ForEach` view. For example, suppose you have
  /// a feature that contains an `IdentifiedArray` of child features like so:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  ///   @ObservableState
  ///   struct State {
  ///     var rows: IdentifiedArrayOf<Child.State> = []
  ///   }
  ///   enum Action {
  ///     case rows(IdentifiedActionOf<Child>)
  ///   }
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       // Core feature logic
  ///     }
  ///     .forEach(\.rows, action: \.rows) {
  ///       Child()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// Then in the view you can use this operator, with `ForEach`, to derive a store for
  /// each element in the identified collection:
  ///
  /// ```swift
  /// struct FeatureView: View {
  ///   let store: StoreOf<Feature>
  ///
  ///   var body: some View {
  ///     List {
  ///       ForEach(store.scope(state: \.rows, action: \.rows) { store in
  ///         ChildView(store: store)
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
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
          Scoping from uncached \(self) is not compatible with observation. Ensure that all parent \
          store scoping operations take key paths and case key paths instead of transform \
          functions, which have been deprecated.
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
    guard self.ids.indices.contains(position)
    else {
      return Store()
    }
    let id = self.ids[position]
    return self.store.scope(
      state: { $0[id: id]! },
      id: self.store.id(state: \.[id: id]!, action: \.[id: id]),
      action: { .element(id: id, action: $0) },
      isInvalid: { !$0.ids.contains(id) },
      removeDuplicates: nil
    )
  }
}
