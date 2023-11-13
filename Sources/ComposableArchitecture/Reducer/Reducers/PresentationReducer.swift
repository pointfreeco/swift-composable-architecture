@_spi(Reflection) import CasePaths
import Combine

/// A property wrapper for state that can be presented.
///
/// Use this property wrapper for modeling a feature's domain that needs to present a child feature
/// using ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at``.
///
/// For example, if you have a `ChildFeature` reducer that encapsulates the logic and behavior for a
/// feature, then any feature that wants to present that feature will hold onto `ChildFeature.State`
/// like so:
///
/// ```swift
/// @Reducer
/// struct ParentFeature {
///   struct State {
///     @PresentationState var child: ChildFeature.State?
///      // ...
///   }
///   // ...
/// }
/// ```
///
/// For the most part your feature's logic can deal with `child` as a plain optional value, but
/// there are times you need to know that you are secretly dealing with `PresentationState`. For
/// example, when using the ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` reducer operator to
/// integrate the parent and child features together, you will construct a key path to the projected
/// value `\.$child`:
///
/// ```swift
/// @Reducer
/// struct ParentFeature {
///   // ...
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       // Core logic for parent feature
///     }
///     .ifLet(\.$child, action: \.child) {
///       ChildFeature()
///     }
///   }
/// }
/// ```
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:TreeBasedNavigation> for information on modeling navigation
/// using optionals and enums.
@propertyWrapper
public struct PresentationState<State> {
  private class Storage: @unchecked Sendable {
    var state: State?
    init(state: State?) {
      self.state = state
    }
  }

  private var storage: Storage
  @usableFromInline var presentedID: NavigationIDPath?

  public init(wrappedValue: State?) {
    self.storage = Storage(state: wrappedValue)
  }

  public var wrappedValue: State? {
    _read { yield self.storage.state }
    _modify {
      if !isKnownUniquelyReferenced(&self.storage) {
        self.storage = Storage(state: self.storage.state)
      }
      yield &self.storage.state
    }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
    _modify { yield &self }
  }

  /// Accesses the value associated with the given case for reading and writing.
  ///
  /// > Note: Accessing the wrong case will result in a runtime warning.
  public subscript<Case>(case path: CaseKeyPath<State, Case>) -> Case?
  where State: CasePathable {
    _read { yield self[case: AnyCasePath(path)] }
    _modify { yield &self[case: AnyCasePath(path)] }
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  public subscript<Case>(case path: AnyCasePath<State, Case>) -> Case? {
    _read { yield self.wrappedValue.flatMap(path.extract) }
    _modify {
      let root = self.wrappedValue
      var value = root.flatMap(path.extract)
      let success = value != nil
      yield &value
      guard success else {
        var description: String?
        if let root = root,
          let metadata = EnumMetadata(State.self),
          let caseName = metadata.caseName(forTag: metadata.tag(of: root))
        {
          description = caseName
        }
        runtimeWarn(
          """
          Can't modify unrelated case\(description.map { " \($0.debugDescription)" } ?? "")
          """
        )
        return
      }
      self.wrappedValue = value.map(path.embed)
    }
  }

  func sharesStorage(with other: Self) -> Bool {
    self.storage === other.storage
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

extension PresentationState: Sendable where State: Sendable {}

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
/// feature using ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at``.
///
/// For example, if you have a `ChildFeature` reducer that encapsulates the logic and behavior
/// for a feature, then any feature that wants to present that feature will hold onto
/// `ChildFeature.Action` like so:
///
/// ```swift
/// @Reducer
/// struct ParentFeature {
///   // ...
///   enum Action {
///     case child(PresentationAction<ChildFeature.Action>)
///      // ...
///   }
///   // ...
/// }
/// ```
///
/// The ``PresentationAction`` enum has two cases that represent the two fundamental operations
/// you can do when presenting a child feature: ``PresentationAction/presented(_:)`` represents
/// an action happening _inside_ the child feature, and ``PresentationAction/dismiss`` represents
/// dismissing the child feature by `nil`-ing its state.
///
/// See the dedicated article on <doc:Navigation> for more information on the library's navigation
/// tools, and in particular see <doc:TreeBasedNavigation> for information on modeling navigation
/// using optionals and enums.
public enum PresentationAction<Action> {
  /// An action sent to `nil` out the associated presentation state.
  case dismiss

  /// An action sent to the associated, non-`nil` presentation state.
  indirect case presented(Action)
}

extension PresentationAction: CasePathable {
  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  @dynamicMemberLookup
  public struct AllCasePaths {
    public var dismiss: AnyCasePath<PresentationAction, Void> {
      AnyCasePath(
        embed: { .dismiss },
        extract: {
          guard case .dismiss = $0 else { return nil }
          return ()
        }
      )
    }

    public var presented: AnyCasePath<PresentationAction, Action> {
      AnyCasePath(
        embed: PresentationAction.presented,
        extract: {
          guard case let .presented(value) = $0 else { return nil }
          return value
        }
      )
    }

    public subscript<AppendedAction>(
      dynamicMember keyPath: CaseKeyPath<Action, AppendedAction>
    ) -> AnyCasePath<PresentationAction, AppendedAction>
    where Action: CasePathable {
      AnyCasePath<PresentationAction, AppendedAction>(
        embed: { .presented(keyPath($0)) },
        extract: {
          guard case let .presented(action) = $0 else { return nil }
          return action[case: keyPath]
        }
      )
    }

    @_disfavoredOverload
    public subscript<AppendedAction>(
      dynamicMember keyPath: CaseKeyPath<Action, AppendedAction>
    ) -> AnyCasePath<PresentationAction, PresentationAction<AppendedAction>>
    where Action: CasePathable {
      AnyCasePath<PresentationAction, PresentationAction<AppendedAction>>(
        embed: {
          switch $0 {
          case .dismiss:
            return .dismiss
          case let .presented(action):
            return .presented(keyPath(action))
          }
        },
        extract: {
          switch $0 {
          case .dismiss:
            return .dismiss
          case let .presented(action):
            return action[case: keyPath].map { .presented($0) }
          }
        }
      )
    }
  }
}

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}
extension PresentationAction: Sendable where Action: Sendable {}
extension PresentationAction: Decodable where Action: Decodable {}
extension PresentationAction: Encodable where Action: Encodable {}

extension Reducer {
  /// Embeds a child reducer in a parent domain that works on an optional property of parent state.
  ///
  /// This version of `ifLet` requires the usage of ``PresentationState`` and ``PresentationAction``
  /// in your feature's domain.
  ///
  /// For example, if a parent feature holds onto a piece of optional child state, then it can
  /// perform its core logic _and_ the child's logic by using the `ifLet` operator:
  ///
  /// ```swift
  /// @Reducer
  /// struct Parent {
  ///   struct State {
  ///     @PresentationState var child: Child.State?
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case child(PresentationAction<Child.Action>)
  ///     // ...
  ///   }
  ///
  ///   var body: some ReducerOf<Self> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .ifLet(\.$child, action: \.child) {
  ///       Child()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// The `ifLet` operator does a number of things to make integrating parent and child features
  /// ergonomic and enforce correctness:
  ///
  ///   * It forces a specific order of operations for the child and parent features:
  ///     * When a ``PresentationAction/dismiss`` action is sent, it runs the parent feature
  ///       before the child state is `nil`'d out. This gives the parent feature an opportunity to
  ///       inspect the child state one last time before the state is cleared.
  ///     * When a ``PresentationAction/presented(_:)`` action is sent it runs the
  ///       child first, and then the parent. If the order was reversed, then it would be possible
  ///       for the parent feature to `nil` out the child state, in which case the child feature
  ///       would not be able to react to that action. That can cause subtle bugs.
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
    action toPresentationAction: CaseKeyPath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _PresentationReducer(
      base: self,
      toPresentationState: toPresentationState,
      toPresentationAction: AnyCasePath(toPresentationAction),
      destination: destination(),
      fileID: fileID,
      line: line
    )
  }

  /// A special overload of ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` for alerts
  /// and confirmation dialogs that does not require a child reducer.
  @warn_unqualified_access
  @inlinable
  public func ifLet<DestinationState: _EphemeralState, DestinationAction>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: CaseKeyPath<Action, PresentationAction<DestinationAction>>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, EmptyReducer<DestinationState, DestinationAction>> {
    self.ifLet(
      toPresentationState,
      action: toPresentationAction,
      destination: {},
      fileID: fileID,
      line: line
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @warn_unqualified_access
  @inlinable
  public func ifLet<DestinationState, DestinationAction, Destination: Reducer>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: AnyCasePath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, Destination>
  where Destination.State == DestinationState, Destination.Action == DestinationAction {
    _PresentationReducer(
      base: self,
      toPresentationState: toPresentationState,
      toPresentationAction: toPresentationAction,
      destination: destination(),
      fileID: fileID,
      line: line
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/Migratingto14#Using-case-key-paths"
  )
  @warn_unqualified_access
  @inlinable
  public func ifLet<DestinationState: _EphemeralState, DestinationAction>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: AnyCasePath<Action, PresentationAction<DestinationAction>>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, EmptyReducer<DestinationState, DestinationAction>> {
    self.ifLet(
      toPresentationState,
      action: toPresentationAction,
      destination: {},
      fileID: fileID,
      line: line
    )
  }
}

public struct _PresentationReducer<Base: Reducer, Destination: Reducer>: Reducer {
  @usableFromInline let base: Base
  @usableFromInline let toPresentationState:
    WritableKeyPath<Base.State, PresentationState<Destination.State>>
  @usableFromInline let toPresentationAction:
    AnyCasePath<Base.Action, PresentationAction<Destination.Action>>
  @usableFromInline let destination: Destination
  @usableFromInline let fileID: StaticString
  @usableFromInline let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    base: Base,
    toPresentationState: WritableKeyPath<Base.State, PresentationState<Destination.State>>,
    toPresentationAction: AnyCasePath<Base.Action, PresentationAction<Destination.Action>>,
    destination: Destination,
    fileID: StaticString,
    line: UInt
  ) {
    self.base = base
    self.toPresentationState = toPresentationState
    self.toPresentationAction = toPresentationAction
    self.destination = destination
    self.fileID = fileID
    self.line = line
  }

  public func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
    let initialPresentationState = state[keyPath: self.toPresentationState]
    let presentationAction = self.toPresentationAction.extract(from: action)

    let destinationEffects: Effect<Base.Action>
    let baseEffects: Effect<Base.Action>

    switch (initialPresentationState.wrappedValue, presentationAction) {
    case let (.some(destinationState), .some(.dismiss)):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
      if self.navigationIDPath(for: destinationState)
        == state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))
      {
        state[keyPath: self.toPresentationState].wrappedValue = nil
      }

    case let (.some(destinationState), .some(.presented(destinationAction))):
      let destinationNavigationIDPath = self.navigationIDPath(for: destinationState)
      destinationEffects = self.destination
        .dependency(
          \.dismiss,
          DismissEffect { @MainActor in
            Task._cancel(id: PresentationDismissID(), navigationID: destinationNavigationIDPath)
          }
        )
        .dependency(\.navigationIDPath, destinationNavigationIDPath)
        .reduce(
          into: &state[keyPath: self.toPresentationState].wrappedValue!, action: destinationAction
        )
        .map { self.toPresentationAction.embed(.presented($0)) }
        ._cancellable(navigationIDPath: destinationNavigationIDPath)
      baseEffects = self.base.reduce(into: &state, action: action)
      if let ephemeralType = ephemeralType(of: destinationState),
        destinationNavigationIDPath
          == state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:)),
        ephemeralType.canSend(destinationAction)
      {
        state[keyPath: self.toPresentationState].wrappedValue = nil
      }

    case (.none, .none), (.some, .none):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)

    case (.none, .some):
      runtimeWarn(
        """
        An "ifLet" at "\(self.fileID):\(self.line)" received a presentation action when \
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
        """
      )
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let presentationIdentityChanged =
      initialPresentationState.presentedID
      != state[keyPath: self.toPresentationState].wrappedValue.map(self.navigationIDPath(for:))

    let dismissEffects: Effect<Base.Action>
    if presentationIdentityChanged,
      let presentedPath = initialPresentationState.presentedID,
      initialPresentationState.wrappedValue.map({
        self.navigationIDPath(for: $0) == presentedPath && !isEphemeral($0)
      })
        ?? true
    {
      dismissEffects = ._cancel(navigationID: presentedPath)
    } else {
      dismissEffects = .none
    }

    if presentationIdentityChanged, state[keyPath: self.toPresentationState].wrappedValue == nil {
      state[keyPath: self.toPresentationState].presentedID = nil
    }

    let presentEffects: Effect<Base.Action>
    if presentationIdentityChanged || state[keyPath: self.toPresentationState].presentedID == nil,
      let presentationState = state[keyPath: self.toPresentationState].wrappedValue,
      !isEphemeral(presentationState)
    {
      let presentationDestinationID = self.navigationIDPath(for: presentationState)
      state[keyPath: self.toPresentationState].presentedID = presentationDestinationID
      presentEffects = .concatenate(
        .publisher { Empty(completeImmediately: false) }
          ._cancellable(id: PresentationDismissID(), navigationIDPath: presentationDestinationID),
        .publisher { Just(self.toPresentationAction.embed(.dismiss)) }
      )
      ._cancellable(navigationIDPath: presentationDestinationID)
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
struct PresentationDismissID: Hashable {
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
  internal static func _cancel<ID: Hashable>(
    id: ID,
    navigationID: NavigationIDPath
  ) {
    withDependencies {
      $0.navigationIDPath = navigationID
    } operation: {
      Task.cancel(id: id)
    }
  }
}

extension Effect {
  internal func _cancellable<ID: Hashable>(
    id: ID = _PresentedID(),
    navigationIDPath: NavigationIDPath,
    cancelInFlight: Bool = false
  ) -> Self {
    withDependencies {
      $0.navigationIDPath = navigationIDPath
    } operation: {
      self.cancellable(id: id, cancelInFlight: cancelInFlight)
    }
  }
  internal static func _cancel<ID: Hashable>(
    id: ID = _PresentedID(),
    navigationID: NavigationIDPath
  ) -> Self {
    withDependencies {
      $0.navigationIDPath = navigationID
    } operation: {
      .cancel(id: id)
    }
  }
}
