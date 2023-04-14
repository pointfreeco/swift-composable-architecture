@_spi(Reflection) import CasePaths
import Combine

/// A property wrapper for state that can be presented.
///
/// Use this property wrapper for modeling a feature's domain that needs to present a child feature
/// using ``Reducer/ifLet(_:action:then:file:fileID:line:)-qgdj``.
@propertyWrapper
public struct PresentationState<State> {
  private var boxedValue: [State]
  @usableFromInline  var isPresented = false

  public init(wrappedValue: State?) {
    self.boxedValue = wrappedValue.map { [$0] } ?? []
  }

  public var wrappedValue: State? {
    _read { yield self.boxedValue.first }
    _modify {
      var state = self.boxedValue.first
      yield &state
      switch (state, self.boxedValue.isEmpty) {
      case (nil, true):
        return
      case (nil, false):
        self.boxedValue = []
      case let (.some(state), true):
        self.boxedValue.insert(state, at: 0)
      case let (.some(state), false):
        self.boxedValue[0] = state
      }
    }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
    _modify { yield &self }
  }

  var id: StableID? {
    self.wrappedValue.map(StableID.init(base:))
  }
}

extension PresentationState: Equatable where State: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

extension PresentationState: Hashable where State: Hashable {
  public func hash(into hasher: inout Hasher) {
    self.wrappedValue.hash(into: &hasher)
  }
}

extension PresentationState: Decodable where State: Decodable {
  public init(from decoder: Decoder) throws {
    do {
      self.init(wrappedValue: try decoder.singleValueContainer().decode(State.self))
    } catch {
      self.init(wrappedValue: try .init(from: decoder))
    }
  }
}

extension PresentationState: Encodable where State: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

extension PresentationState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue as Any)
  }
}

/// A wrapper type for actions that can be presented.
///
/// Use this wrapper type for modeling a feature's domain that needs to present a child
/// feature using ``Reducer/ifLet(_:action:then:file:fileID:line:)-qgdj``.
public enum PresentationAction<Action> {
  case dismiss
  case presented(Action)
}

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}
extension PresentationAction: Sendable where Action: Sendable {}

extension PresentationAction: Decodable where Action: Decodable {}
extension PresentationAction: Encodable where Action: Encodable {}

extension Reducer {
  /// Embeds a child reducer in a parent domain that works on an optional property of parent state.
  ///
  /// For example, if a parent feature holds onto a piece of optional child state, then it can
  /// perform its core logic _and_ the child's logic by using the `ifLet` operator:
  ///
  /// ```swift
  /// struct Parent: Reducer {
  ///   struct State {
  ///     @PresentationState var child: Child.State?
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case child(PresentationAction<Child.Action>)
  ///     // ...
  ///   }
  ///
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .ifLet(\.$child, action: /Action.child) {
  ///       Child()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `ifLet` operator does a number of things to try to enforce correctness:
  ///
  ///   * It forces a specific order of operations for the child and parent features. It runs the
  ///     child first, and then the parent. If the order was reversed, then it would be possible for
  ///     the parent feature to `nil` out the child state, in which case the child feature would not
  ///     be able to react to that action. That can cause subtle bugs.
  ///
  ///   * It automatically cancels all child effects when it detects the child's state is `nil`'d
  ///     out.
  ///
  ///   * Automatically `nil`s out child state when an action is sent for alerts and confirmation
  ///     dialogs.
  ///
  ///   * It gives the child feature access to the ``DismissEffect`` dependency, which allows the
  ///     child feature to dismiss itself without communicating with the parent.
  ///
  /// - Parameters:
  ///   - toPresentationState: A writable key path from parent state to a property containing child
  ///     presentation state.
  ///   - toPresentationAction: A case path from parent action to a case containing child actions.
  ///   - destination: A reducer that will be invoked with child actions against presented child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @warn_unqualified_access
  @inlinable
  public func ifLet<DestinationState, DestinationAction, Destination: Reducer>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> then destination: () -> Destination,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _PresentationReducer(
      base: self,
      toPresentationState: toPresentationState,
      toPresentationAction: toPresentationAction,
      destination: destination(),
      file: file,
      fileID: fileID,
      line: line
    )
  }

  /// A special overload of ``Reducer/ifLet(_:action:then:file:fileID:line:)-qgdj`` for alerts and
  /// confirmation dialogs that does not require a child reducer.
  @warn_unqualified_access
  @inlinable
  public func ifLet<DestinationState: _EphemeralState, DestinationAction>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, EmptyReducer<DestinationState, DestinationAction>> {
    self.ifLet(
      toPresentationState,
      action: toPresentationAction,
      then: { EmptyReducer() },
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _PresentationReducer<Base: Reducer, Destination: Reducer>: Reducer {
  @usableFromInline let base: Base
  @usableFromInline let toPresentationState: WritableKeyPath<
    Base.State, PresentationState<Destination.State>
  >
  @usableFromInline let toPresentationAction: CasePath<
    Base.Action, PresentationAction<Destination.Action>
  >
  @usableFromInline let destination: Destination
  @usableFromInline let file: StaticString
  @usableFromInline let fileID: StaticString
  @usableFromInline let line: UInt

  @usableFromInline @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    base: Base,
    toPresentationState: WritableKeyPath<Base.State, PresentationState<Destination.State>>,
    toPresentationAction: CasePath<Base.Action, PresentationAction<Destination.Action>>,
    destination: Destination,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.base = base
    self.toPresentationState = toPresentationState
    self.toPresentationAction = toPresentationAction
    self.destination = destination
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> EffectTask<Base.Action> {

    let initialPresentationState = state[keyPath: self.toPresentationState]
    let presentationAction = self.toPresentationAction.extract(from: action)

    let destinationEffects: EffectTask<Base.Action>
    let baseEffects: EffectTask<Base.Action>

    switch (initialPresentationState.wrappedValue, presentationAction) {
    case let (.some(destinationState), .some(.dismiss)):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
      if self.navigationIDPath(for: destinationState)
        == state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))
      {
        state[keyPath: self.toPresentationState].wrappedValue = nil
      }
    // TODO: Should we runtime warn if `base` changes the destination during dismissal, instead?

    case let (.some(destinationState), .some(.presented(destinationAction))):
      let destinationNavigationIDPath = self.navigationIDPath(for: destinationState)
      destinationEffects = self.destination
        .dependency(\.dismiss, DismissEffect { @MainActor in
          Task._cancel(id: DismissID(), navigationID: destinationNavigationIDPath)
        })
        .dependency(\.navigationIDPath, destinationNavigationIDPath)
        .reduce(
          into: &state[keyPath: self.toPresentationState].wrappedValue!, action: destinationAction
        )
        .map { self.toPresentationAction.embed(.presented($0)) }
        ._cancellable(id: _PresentedID(), navigationIDPath: destinationNavigationIDPath)
      baseEffects = self.base.reduce(into: &state, action: action)
      if isEphemeral(destinationState),
        destinationNavigationIDPath
          == state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))
      {
        state[keyPath: self.toPresentationState].wrappedValue = nil
      }

    case (.none, .none), (.some, .none):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)

    case (.none, .some):
      runtimeWarn(
        """
        A "ifLet" at "\(self.fileID):\(self.line)" received a presentation action when \
        destination state was absent. …

          Action:
            \(debugCaseOutput(action))

        This is generally considered an application logic error, and can happen for a few \
        reasons:

        • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
        must run before any other reducer sets destination state to "nil". This ensures that \
        destination reducers can handle their actions while their state is still present.

        • This action was sent to the store while destination state was "nil". Make sure that \
        actions for this reducer can only be sent from a view store when state is present, or \
        from effects that start from this reducer. In SwiftUI applications, use a Composable \
        Architecture view modifier like "sheet(store:…)".
        """,
        file: self.file,
        line: self.line
      )
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let presentationIdentityChanged =
    initialPresentationState.wrappedValue.map(self.navigationIDPath(for:))
    != state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))

    let dismissEffects: EffectTask<Base.Action>
    if presentationIdentityChanged,
      let presentationState = initialPresentationState.wrappedValue,
      !isEphemeral(presentationState)
    {
      dismissEffects = ._cancel(navigationID: self.navigationIDPath(for: presentationState))
    } else {
      dismissEffects = .none
    }

    let presentEffects: EffectTask<Base.Action>
    if presentationIdentityChanged || !state[keyPath: self.toPresentationState].isPresented,
      let presentationState = state[keyPath: self.toPresentationState].wrappedValue,
      !isEphemeral(presentationState)
    {
      let presentationDestinationID = self.navigationIDPath(for: presentationState)
      state[keyPath: self.toPresentationState].isPresented = true
      presentEffects = Empty(completeImmediately: false)
        .eraseToEffect()
        ._cancellable(id: DismissID(), navigationIDPath: presentationDestinationID)
        .append(Just(self.toPresentationAction.embed(.dismiss)))
        .eraseToEffect()
        ._cancellable(id: _PresentedID(), navigationIDPath: presentationDestinationID)
        ._cancellable(id: OnFirstAppearID(), navigationIDPath: .init())
    } else {
      presentEffects = .none
    }

    return .merge(
      destinationEffects,
      baseEffects,
      dismissEffects,
      presentEffects
    )
  }

  @usableFromInline
  func navigationIDPath(for state: Destination.State) -> NavigationIDPath {
    self.navigationIDPath.appending(
      NavigationID(
        base: state,
        keyPath: self.toPresentationState.appending(path: \.wrappedValue)
      )
    )
  }
}

@usableFromInline
struct DismissID: Hashable {
  @usableFromInline init() {}
}
@usableFromInline
struct OnFirstAppearID: Hashable {
  @usableFromInline init() {}
}

public struct _PresentedID: Hashable {
  @inlinable
  public init() {
    self.init(internal: ())
  }

  @usableFromInline
  init(internal: Void) {}
}

extension Task where Success == Never, Failure == Never {
  @usableFromInline
  internal static func _cancel(
    id: AnyHashable,
    navigationID: NavigationIDPath
  ) {
    withDependencies { $0.navigationIDPath = navigationID } operation: {
      Task.cancel(id: id)
    }
  }
}
extension EffectPublisher {
  @usableFromInline
  internal func _cancellable(
    id: AnyHashable,
    navigationIDPath: NavigationIDPath,
    cancelInFlight: Bool = false
  ) -> Self {
    withDependencies { $0.navigationIDPath = navigationIDPath } operation: {
      self.cancellable(id: id, cancelInFlight: cancelInFlight)
    }
  }
  @usableFromInline
  internal static func _cancel(
    id: AnyHashable = _PresentedID(),
    navigationID: NavigationIDPath
  ) -> Self {
    withDependencies { $0.navigationIDPath = navigationID } operation: {
      .cancel(id: id)
    }
  }
}

struct StableID: Hashable, Identifiable, Sendable {
  private let identifier: AnyHashableSendable?
  private let tag: UInt32?
  private let type: Any.Type

  init<Base>(base: Base) {
    self.tag = EnumMetadata(Base.self)?.tag(of: base)
    if let id = _identifiableID(base) ?? EnumMetadata.project(base).flatMap(_identifiableID) {
      self.identifier = AnyHashableSendable(id)
    } else {
      self.identifier = nil
    }
    self.type = Base.self
  }

  var id: Self { self }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.identifier == rhs.identifier
    && lhs.tag == rhs.tag
    && lhs.type == rhs.type
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.identifier)
    hasher.combine(self.tag)
    hasher.combine(ObjectIdentifier(self.type))
  }
}
