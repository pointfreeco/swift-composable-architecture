struct ExtractionFailed: Error {}
struct EmbeddingFailed: Error {}
struct StateExtractionFailed: Error {}

public protocol FailableStateDerivation {
  associatedtype Source
  associatedtype Destination
  func extract(from source: Source) -> Destination?
}

public protocol StateDerivation: FailableStateDerivation {
  func get(from source: Source) -> Destination
}

@rethrows
public protocol MutableFailableStateDerivation: FailableStateDerivation {
  func embed(into source: inout Source, destination: Destination?) throws
  func modify<Result>(source: inout Source, _ body: (inout Destination?) throws -> Result) throws
    -> Result
}

extension MutableFailableStateDerivation {
  public func modify<Result>(source: inout Source, _ body: (inout Destination?) throws -> Result)
    throws
    -> Result
  {
    var destination = self.extract(from: source)
    let result = try body(&destination)
    try self.embed(into: &source, destination: destination)
    return result
  }
}

public protocol MutableStateDerivation: MutableFailableStateDerivation & StateDerivation {
  func embed(into source: inout Source, destination: Destination)
  func modify<Result>(source: inout Source, _ body: (inout Destination) throws -> Result) rethrows
    -> Result
}

extension MutableStateDerivation {
  public func embed(into source: inout Source, destination: Destination?) throws {
    guard let destination = destination else { throw EmbeddingFailed() }
    self.embed(into: &source, destination: destination)
  }

  public func modify<Result>(source: inout Source, _ body: (inout Destination) -> Result) throws
    -> Result
  {
    var destination = self.get(from: source)
    let result = body(&destination)
    self.embed(into: &source, destination: destination)
    return result
  }
}

extension KeyPath: StateDerivation {
  public func extract(from source: Root) -> Value? {
    source[keyPath: self]
  }
  public func get(from source: Root) -> Value {
    source[keyPath: self]
  }
}

extension WritableKeyPath: MutableStateDerivation {
  public func embed(into source: inout Root, destination: Value) {
    source[keyPath: self] = destination
  }
  public func modify<Result>(source: inout Root, _ body: (inout Value) throws -> Result) rethrows
    -> Result
  {
    try body(&source[keyPath: self])
  }
}

extension CasePath: MutableFailableStateDerivation {
  public func embed(into source: inout Root, destination: Value?) throws {
    guard let destination = destination else { throw EmbeddingFailed() }
    source = self.embed(destination)
  }
  public func modify<Result>(source: inout Root, _ body: (inout Value?) throws -> Result) throws
    -> Result
  {
    guard let extracted = self.extract(from: source) else { throw ExtractionFailed() }
    var destination: Value? = extracted
    let result = try body(&destination)
    try self.embed(into: &source, destination: destination)
    return result
  }
}

@rethrows
public protocol StateContainer {
  associatedtype State
  associatedtype Tag

  func extract(tag: Tag) -> State?
  mutating func embed(tag: Tag, state: State)

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

  /// Attempts to modify a ``State`` at ``Tag``.
  ///
  /// This method allows adopters to perform modifications in-place in compatible containers.
  ///
  /// A default implementation is provided.
  ///
  /// - Parameters:
  ///   - tag: The ``Tag`` of the ``State`` to modify.
  ///   - body: A closure that can mutate the ``State`` at `tag`. If the closure throws, the
  ///   container will be left unmodified.
  /// - Returns: The return value, if any, of the body closure.
  mutating func modify<Result>(tag: Tag, _ body: (inout State) -> Result) throws -> Result
}

extension StateContainer {
  public func contains(tag: Tag) -> Bool {
    self.extract(tag: tag) != nil
  }
  public mutating func modify<Result>(tag: Tag, _ body: (inout State) -> Result) throws
    -> Result
  {
    guard var state = self.extract(tag: tag) else { throw StateExtractionFailed() }
    defer { self.embed(tag: tag, state: state) }
    return body(&state)
  }
}

extension CasePath {
  @usableFromInline
  func with<Tag>(tag: Tag) -> CasePath<Root, (Tag, Value)> {
    CasePath<Root, (Tag, Value)> {
      self.embed($0.1)
    } extract: {
      self.extract(from: $0).map { (tag, $0) }
    }
  }
}

@usableFromInline
struct StateExtractionFailureHandler<State, Action>: Sendable {
  @usableFromInline
  let handle:
    @Sendable (
      _ state: State,
      _ action: Action,
      _ file: StaticString,
      _ fileID: StaticString,
      _ line: UInt
    ) -> Void

  @usableFromInline
  init(
    handle: @escaping @Sendable (
      _ state: State,
      _ action: Action,
      _ file: StaticString,
      _ fileID: StaticString,
      _ line: UInt
    ) -> Void
  ) {
    self.handle = handle
  }

  @usableFromInline
  func callAsFunction(
    state: State,
    action: Action,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    handle(state, action, file, fileID, line)
  }
}

public struct _ContainedStateReducer<
  Parent: ReducerProtocol,
  Derivation: MutableFailableStateDerivation,
  Container: StateContainer,
  Element: ReducerProtocol
>: ReducerProtocol
where
  Derivation.Source == Parent.State,
  Derivation.Destination == Container,
  Container.State == Element.State
{
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toStateContainer: Derivation

  @usableFromInline
  let toContainedAction: CasePath<Parent.Action, (Container.Tag, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @usableFromInline
  let stateExtractionFailureHandler:
    () -> StateExtractionFailureHandler<Parent.State, Parent.Action>?

  @usableFromInline
  init(
    parent: Parent,
    toStateContainer: Derivation,
    toContainedAction: CasePath<Parent.Action, (Container.Tag, Element.Action)>,
    element: Element,
    file: StaticString,
    fileID: StaticString,
    line: UInt,
    onStateExtractionFailure: @escaping @autoclosure () -> StateExtractionFailureHandler<
      Parent.State, Parent.Action
    >? = nil
  ) {
    self.parent = parent
    self.toStateContainer = toStateContainer
    self.toContainedAction = toContainedAction
    self.element = element
    self.file = file
    self.fileID = fileID
    self.line = line
    self.stateExtractionFailureHandler = onStateExtractionFailure
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    self.reduceContained(into: &state, action: action)
      .merge(with: self.parent.reduce(into: &state, action: action))
  }

  @inlinable
  func reduceContained(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    guard let (tag, elementAction) = self.toContainedAction.extract(from: action) else {
      return .none
    }

    guard self.toStateContainer.extract(from: state)?.contains(tag: tag) == true else {
      self.stateExtractionFailureHandler()?(
        state: state,
        action: action,
        file: self.file,
        fileID: self.fileID,
        line: self.line
      )
      return .none
    }

    return try! self.toStateContainer.modify(source: &state) { stateContainer in
      try! stateContainer!.modify(tag: tag) { elementState in
        self.element.reduce(into: &elementState, action: elementAction)
      }
    }.map { self.toContainedAction.embed((tag, $0)) }
  }
}
