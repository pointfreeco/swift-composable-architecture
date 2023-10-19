import Foundation
import OrderedCollections

public protocol CollectionAction<Elements> {
  associatedtype Elements: Collection
  associatedtype ID: Hashable = Elements.Index
  associatedtype ElementAction

  static func element(id: ID, action: ElementAction) -> Self
  static func id(at index: Elements.Index, elements: Elements) -> ID
  static func index(at id: ID, elements: Elements) -> Elements.Index?

  var element: (id: ID, action: ElementAction)? { get }
}

public protocol RangeReplaceableCollectionAction<Elements>: CollectionAction {
  static func setElements(_ elements: Elements) -> Self
}

extension CollectionAction where ID == Elements.Index {
  public static func id(at index: Elements.Index, elements _: Elements) -> Elements.Index {
    index
  }

  public static func index(at id: Elements.Index, elements: Elements) -> Elements.Index? {
    elements.indices.contains(id) ? id : nil
  }
}

public enum IndexedAction<Elements: Collection, ElementAction>: CollectionAction
where Elements.Index: Hashable {
  case element(id: Elements.Index, action: ElementAction)

  public var element: (id: Elements.Index, action: ElementAction)? {
    switch self {
    case let .element(id, action):
      return (id, action)
    }
  }
}

public typealias ArrayAction<Element: Reducer> = IndexedAction<[Element.State], Element.Action>

extension Store: MutableCollection, Collection, Sequence
where
  State: MutableCollection,
  State.Index: Hashable,
  Action: CollectionAction,
  Action.Elements == State
{
  public var startIndex: State.Index { self.stateSubject.value.startIndex }
  public var endIndex: State.Index { self.stateSubject.value.endIndex }
  public func index(after i: State.Index) -> State.Index { self.stateSubject.value.index(after: i) }

  public subscript(position: State.Index) -> Store<State.Element, Action.ElementAction>
  where State.Index: Sendable {
    get {
      self.scope(
        state: { $0[Action.index(at: Action.id(at: position, elements: $0), elements: $0)!] },
        action: { .element(id: Action.id(at: position, elements: $0), action: $1) },
        isAttached: {
          $0.indices.contains(position)
            && Action.index(at: Action.id(at: position, elements: $0), elements: $0) != nil
        },
        removeDuplicates: nil
      )
    }
    set { /* self.children[id] = newValue */  }
  }
}

extension Store: BidirectionalCollection
where
  State: BidirectionalCollection & MutableCollection,
  State.Index: Hashable,
  Action: CollectionAction,
  Action.Elements == State
{
  public func index(before i: State.Index) -> State.Index {
    self.stateSubject.value.index(before: i)
  }
}

extension Store: RandomAccessCollection
where
  State: RandomAccessCollection & MutableCollection,
  State.Index: Hashable,
  Action: CollectionAction,
  Action.Elements == State
{}

public enum IdentifiedArrayAction<Element: Reducer>: CollectionAction
where Element.State: Identifiable {
  case element(id: Element.State.ID, action: Element.Action)

  public static func id(at index: Int, elements: IdentifiedArrayOf<Element.State>)
    -> Element.State.ID
  {
    elements.ids[index]
  }

  public static func index(at id: Element.State.ID, elements: IdentifiedArrayOf<Element.State>)
    -> Int?
  {
    elements.index(id: id)
  }

  public var element: (id: Element.State.ID, action: Element.Action)? {
    switch self {
    case let .element(id, action):
      return (id, action)
    }
  }
}

extension Reducer {
  public func forEach<
    ElementsState: MutableCollection,
    ElementsAction: CollectionAction<ElementsState>
  >(
    _ stateKeyPath: WritableKeyPath<State, ElementsState>,
    action actionCasePath: CasePath<Action, ElementsAction>,
    @ReducerBuilder<ElementsState.Element, ElementsAction.ElementAction> _ element:
      () -> some Reducer<ElementsState.Element, ElementsAction.ElementAction>
  ) -> some ReducerOf<Self>
  where
    ElementsState.Element: ObservableState,
    ElementsState.Index: Hashable & Sendable
  {
    _ForEachCollectionReducer(
      base: self,
      stateKeyPath: stateKeyPath,
      actionCasePath: actionCasePath,
      element: element()
    )
  }
}

private struct _ForEachCollectionReducer<
  Base: Reducer,
  ElementsState: MutableCollection,
  ElementsAction: CollectionAction<ElementsState>,
  Element: Reducer<ElementsState.Element, ElementsAction.ElementAction>
>: Reducer
where
  ElementsState.Element: ObservableState,
  ElementsState.Index: Hashable & Sendable
{
  let base: Base
  let stateKeyPath: WritableKeyPath<Base.State, ElementsState>
  let actionCasePath: CasePath<Base.Action, ElementsAction>
  let element: Element

  func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
    var elementEffects: Effect<Base.Action> = .none
    element: if let elementAction = self.actionCasePath.extract(from: action) {
      guard let element = elementAction.element
      else { break element }
      guard let index = ElementsAction.index(at: element.id, elements: state[keyPath: stateKeyPath])
      else {
        // TODO: runtimeWarn
        break element
      }
      elementEffects = self.element
        .reduce(
          into: &state[keyPath: self.stateKeyPath][index],
          action: element.action
        )
        .map { self.actionCasePath.embed(.element(id: element.id, action: $0)) }
    }
    return .merge(
      elementEffects,
      self.base.reduce(into: &state, action: action)
    )
  }
}

