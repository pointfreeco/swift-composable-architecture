import OrderedCollections

/// A wrapper type for actions that can be presented in a list.
///
/// Use this type for modeling a feature's domain that needs to present child features using
/// ``Reducer/forEach(_:action:element:fileID:line:)-247po``.
public enum IdentifiedAction<ID: Hashable, Action>: CasePathable {
  /// An action sent to the element at a given identifier.
  case element(id: ID, action: Action)

  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  public struct AllCasePaths {
    public var element: AnyCasePath<IdentifiedAction, (id: ID, action: Action)> {
      AnyCasePath(
        embed: IdentifiedAction.element,
        extract: {
          guard case let .element(id, action) = $0 else { return nil }
          return (id, action)
        }
      )
    }

    public subscript(id id: ID) -> AnyCasePath<IdentifiedAction, Action> {
      AnyCasePath(
        embed: { .element(id: id, action: $0) },
        extract: {
          guard case .element(id, let action) = $0 else { return nil }
          return action
        }
      )
    }
  }
}

extension IdentifiedAction: Equatable where Action: Equatable {}
extension IdentifiedAction: Hashable where Action: Hashable {}
extension IdentifiedAction: Sendable where ID: Sendable, Action: Sendable {}

extension IdentifiedAction: Decodable where ID: Decodable, Action: Decodable {}
extension IdentifiedAction: Encodable where ID: Encodable, Action: Encodable {}

public typealias IdentifiedActionOf<R: Reducer> = IdentifiedAction<R.State.ID, R.Action>
where R.State: Identifiable

extension Reducer {
  /// Embeds a child reducer in a parent domain that works on elements of a collection in parent
  /// state.
  ///
  /// For example, if a parent feature holds onto an array of child states, then it can perform
  /// its core logic _and_ the child's logic by using the `forEach` operator:
  ///
  /// ```swift
  /// @Reducer
  /// struct Parent {
  ///   struct State {
  ///     var rows: IdentifiedArrayOf<Row.State>
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case rows(IdentifiedActionOf<Row>)
  ///     // ...
  ///   }
  ///
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .forEach(\.rows, action: \.rows) {
  ///       Row()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// > Tip: We are using `IdentifiedArray` from our
  /// [Identified Collections][swift-identified-collections] library because it provides a safe
  /// and ergonomic API for accessing elements from a stable ID rather than positional indices.
  ///
  /// The `forEach` forces a specific order of operations for the child and parent features. It
  /// runs the child first, and then the parent. If the order was reversed, then it would be
  /// possible for the parent feature to remove the child state from the array, in which case the
  /// child feature would not be able to react to that action. That can cause subtle bugs.
  ///
  /// It is still possible for a parent feature higher up in the application to remove the child
  /// state from the array before the child has a chance to react to the action. In such cases a
  /// runtime warning is shown in Xcode to let you know that there's a potential problem.
  ///
  /// [swift-identified-collections]: http://github.com/pointfreeco/swift-identified-collections
  ///
  /// - Parameters:
  ///   - toElementsState: A writable key path from parent state to an `IdentifiedArray` of child
  ///     state.
  ///   - toElementAction: A case path from parent action to an ``IdentifiedAction`` of child
  ///     actions.
  ///   - element: A reducer that will be invoked with child actions against elements of child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  @warn_unqualified_access
  public func forEach<ElementState, ElementAction, ID: Hashable, Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: CaseKeyPath<Action, IdentifiedAction<ID, ElementAction>>,
    @ReducerBuilder<ElementState, ElementAction> element: () -> Element,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, ID, Element>
  where ElementState == Element.State, ElementAction == Element.Action {
    _ForEachReducer(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: AnyCasePath(toElementAction.appending(path: \.element)),
      element: element(),
      fileID: fileID,
      line: line
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use a case key path to an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use a case key path to an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use a case key path to an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use a case key path to an 'IdentifiedAction', instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4"
  )
  @inlinable
  @warn_unqualified_access
  public func forEach<ElementState, ElementAction, ID: Hashable, Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: AnyCasePath<Action, (ID, ElementAction)>,
    @ReducerBuilder<ElementState, ElementAction> element: () -> Element,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, ID, Element>
  where ElementState == Element.State, ElementAction == Element.Action {
    _ForEachReducer(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: .init(
        embed: toElementAction.embed,
        extract: toElementAction.extract
      ),
      element: element(),
      fileID: fileID,
      line: line
    )
  }
}

public struct _ForEachReducer<
  Parent: Reducer, ID: Hashable, Element: Reducer
>: Reducer {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>

  @usableFromInline
  let toElementAction: AnyCasePath<Parent.Action, (id: ID, action: Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>,
    toElementAction: AnyCasePath<Parent.Action, (id: ID, action: Element.Action)>,
    element: Element,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.fileID = fileID
    self.line = line
  }

  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    let elementEffects = self.reduceForEach(into: &state, action: action)

    let idsBefore = state[keyPath: self.toElementsState].ids
    let parentEffects = self.parent.reduce(into: &state, action: action)
    let idsAfter = state[keyPath: self.toElementsState].ids

    let elementCancelEffects: Effect<Parent.Action> =
      areOrderedSetsDuplicates(idsBefore, idsAfter)
      ? .none
      : .merge(
        idsBefore.subtracting(idsAfter).map {
          ._cancel(
            id: NavigationID(id: $0, keyPath: self.toElementsState),
            navigationID: self.navigationIDPath
          )
        }
      )

    return .merge(
      elementEffects,
      parentEffects,
      elementCancelEffects
    )
  }

  func reduceForEach(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    if state[keyPath: self.toElementsState][id: id] == nil {
      runtimeWarn(
        """
        A "forEach" at "\(self.fileID):\(self.line)" received an action for a missing element. …

          Action:
            \(debugCaseOutput(action))

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer removed an element with this ID before this reducer ran. This reducer \
        must run before any other reducer removes an element, which ensures that element reducers \
        can handle their actions while their state is still available.

        • An in-flight effect emitted this action when state contained no element at this ID. \
        While it may be perfectly reasonable to ignore this action, consider canceling the \
        associated effect before an element is removed, especially if it is a long-living effect.

        • This action was sent to the store while its state contained no element at this ID. To \
        fix this make sure that actions for this reducer can only be sent from a view store when \
        its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
        """
      )
      return .none
    }
    let navigationID = NavigationID(id: id, keyPath: self.toElementsState)
    let elementNavigationID = self.navigationIDPath.appending(navigationID)
    return self.element
      .dependency(\.navigationIDPath, elementNavigationID)
      .reduce(into: &state[keyPath: self.toElementsState][id: id]!, action: elementAction)
      .map { self.toElementAction.embed((id, $0)) }
      ._cancellable(id: navigationID, navigationIDPath: self.navigationIDPath)
  }
}
