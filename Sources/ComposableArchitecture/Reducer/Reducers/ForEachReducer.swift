import OrderedCollections

/// A protocol that describes container types from which one can extract some domain's `State`
/// value.
///
/// This protocol is semi-abstract and you usually conform to the ``MutableStateContainer`` and/or
/// the ``IdentifiedStatesCollection`` which inherit from this protocol.
public protocol StateContainer {
  /// The type of values that can be extracted from this container.
  associatedtype State
  /// A type whose values allow identify a specific ``State`` in this container.
  ///
  /// ``StateContainer`` doesn't impose any requirement on ``Tag``. It can be the `Key` of a
  /// `Dictionary`, the `ID` of an `IdentifiedArray`, or even `Void` or `Self.Type` when the
  ///  container can only contain one unique value.
  associatedtype Tag
  /// Extracts a ``State`` for a given ``Tag`` from this container
  ///
  /// - Parameters:
  ///   - tag: The ``Tag`` of the ``State`` to extract.
  /// - Returns: A ``State`` value if the extraction succeeds, `nil` otherwise.
  func extract(tag: Tag) -> State?
  /// Checks if a container contains a ``State`` for a given ``Tag``
  ///
  /// This method allows adopters to optimize situations where the client only wants to check if the
  /// container contains a ``State`` without needing the value itself. This can be useful if the
  /// extraction of a value is an heavier operation than simply checking its existence.
  ///
  /// A default implementation is provided.
  ///
  /// - Parameters:
  ///   - tag: The ``Tag`` of the ``State`` to check.
  /// - Returns: `true` if a ``State`` exists at `tag`, `false` otherwise.
  func contains(tag: Tag) -> Bool
}

extension StateContainer {
  @inlinable
  public func contains(tag: Tag) -> Bool {
    self.extract(tag: tag) != nil
  }
}

/// A mutable version of ``StateContainer``, where the extracted ``State`` can be embedded back into
/// the container.
///
/// The library ships with two adopters of this protocol: `IdentifiedArray` from our
/// [Identified Collections][swift-identified-collections] library, and `OrderedDictionary` from
/// [Swift Collections][swift-collections].
///
/// > Tip: We recommend to use `IdentifiedArray` from our
/// [Identified Collections][swift-identified-collections] library because it provides a safe
/// and ergonomic API for accessing elements from a stable ID rather than positional indices.
///
/// [swift-identified-collections]: http://github.com/pointfreeco/swift-identified-collections
/// [swift-collections]: http://github.com/apple/swift-collections
public protocol MutableStateContainer: StateContainer {
  /// Write a ``State`` value with a given ``Tag`` into the container.
  /// - Parameters:
  ///   - tag: A ``Tag`` of the ``State`` to embed.
  ///   - state: The ``State`` value that will be embedded.
  mutating func embed(tag: Tag, state: State)
  /// Attempts to modify a ``State`` at ``Tag``.
  ///
  /// This method allows adopters to perform modifications in-place in compatible containers.
  ///
  /// The function should throw if it fails to extract a ``State``. In this case, the container
  /// should be left unmodified.
  ///
  /// A default implementation is provided.
  ///
  /// - Parameters:
  ///   - tag: The ``Tag`` of the ``State`` to modify.
  ///   - body: A closure that can mutate the ``State`` at `tag`.
  /// - Returns: The return value, if any, of the body closure.
  mutating func modify<Result>(tag: Tag, _ body: (inout State) -> Result) throws -> Result
}

@usableFromInline
struct StateExtractionFailed: Error {
  @usableFromInline init() {}
}

extension MutableStateContainer {
  @inlinable
  public mutating func modify<Result>(tag: Tag, _ body: (inout State) -> Result) throws
    -> Result
  {
    guard var state = self.extract(tag: tag) else { throw StateExtractionFailed() }
    defer { self.embed(tag: tag, state: state) }
    return body(&state)
  }
}

extension IdentifiedArray: MutableStateContainer {
  @inlinable
  public func extract(tag: ID) -> Element? {
    self[id: tag]
  }
  @inlinable
  public mutating func embed(tag: ID, state: Element) {
    self[id: tag] = state
  }
  @inlinable
  public mutating func modify<Value>(tag: ID, _ body: (inout Element) -> Value) -> Value {
    body(&self[id: tag]!)
  }
}

extension OrderedDictionary: MutableStateContainer {
  @inlinable
  public func extract(tag: Key) -> Value? {
    self[tag]
  }
  @inlinable
  public mutating func embed(tag: Key, state: Value) {
    self[tag] = state
  }
  @inlinable
  public mutating func modify<T>(tag: Key, _ body: (inout Value) -> T) -> T {
    body(&self[tag]!)
  }
}

extension ReducerProtocol {
  #if swift(>=5.7)
    /// Embeds a child reducer in a parent domain that works on elements of a collection in parent
    /// state.
    ///
    /// For example, if a parent feature holds onto an array of child states, then it can perform
    /// its core logic _and_ the child's logic by using the `forEach` operator:
    ///
    /// ```swift
    /// struct Parent: ReducerProtocol {
    ///   struct State {
    ///     var rows: IdentifiedArrayOf<Row.State>
    ///     // ...
    ///   }
    ///   enum Action {
    ///     case row(id: Row.State.ID, action: Row.Action)
    ///     // ...
    ///   }
    ///
    ///   var body: some ReducerProtocol<State, Action> {
    ///     Reduce { state, action in
    ///       // Core logic for parent feature
    ///     }
    ///     .forEach(\.rows, action: /Action.row) {
    ///       Row()
    ///     }
    ///   }
    /// }
    /// ```
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
    /// > Tip: We recommend to use `IdentifiedArray` from our
    /// [Identified Collections][swift-identified-collections] library because it provides a safe
    /// and ergonomic API for accessing elements from a stable ID rather than positional indices.
    ///
    /// [swift-identified-collections]: http://github.com/pointfreeco/swift-identified-collections
    ///
    /// - Parameters:
    ///   - toElementsState: A writable key path from parent state to a ``MutableStateContainer`` of
    ///   child states.
    ///   - toElementAction: A case path from parent action to child identifier and child actions.
    ///   - element: A reducer that will be invoked with child actions against elements of child
    ///     state.
    /// - Returns: A reducer that combines the child reducer with the parent reducer.
    @inlinable
    public func forEach<Elements: MutableStateContainer, ElementAction>(
      _ toElementsState: WritableKeyPath<State, Elements>,
      action toElementAction: CasePath<Action, (Elements.Tag, ElementAction)>,
      @ReducerBuilder<Elements.State, ElementAction> _ element: () -> some ReducerProtocol<
        Elements.State, ElementAction
      >,
      file: StaticString = #file,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) -> some ReducerProtocol<State, Action> {
      _ForEachReducer(
        parent: self,
        toElementsState: toElementsState,
        toElementAction: toElementAction,
        element: element(),
        file: file,
        fileID: fileID,
        line: line
      )
    }
  #else
    @inlinable
    public func forEach<Elements: MutableStateContainer, Element: ReducerProtocol>(
      _ toElementsState: WritableKeyPath<State, Elements>,
      action toElementAction: CasePath<Action, (Elements.Tag, Element.Action)>,
      @ReducerBuilderOf<Element> _ element: () -> Element,
      file: StaticString = #file,
      fileID: StaticString = #fileID,
      line: UInt = #line
    ) -> _ForEachReducer<Self, Elements, Element> {
      _ForEachReducer(
        parent: self,
        toElementsState: toElementsState,
        toElementAction: toElementAction,
        element: element(),
        file: file,
        fileID: fileID,
        line: line
      )
    }
  #endif
}

public struct _ForEachReducer<
  Parent: ReducerProtocol,
  Container: MutableStateContainer,
  Element: ReducerProtocol
>: ReducerProtocol where Container.State == Element.State {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: WritableKeyPath<Parent.State, Container>

  @usableFromInline
  let toElementAction: CasePath<Parent.Action, (Container.Tag, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @usableFromInline
  init(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, Container>,
    toElementAction: CasePath<Parent.Action, (Container.Tag, Element.Action)>,
    element: Element,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    self.reduceForEach(into: &state, action: action)
      .merge(with: self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceForEach(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    guard state[keyPath: self.toElementsState].contains(tag: id) else {
      runtimeWarn(
        """
        A "forEach" at "\(self.fileID):\(self.line)" received an action for a missing element.

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
        """,
        file: self.file,
        line: self.line
      )
      return .none
    }
    return try! state[keyPath: self.toElementsState].modify(tag: id) {
      self.element.reduce(into: &$0, action: elementAction)
    }.map { self.toElementAction.embed((id, $0)) }
  }
}
