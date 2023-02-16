@_spi(Reflection) import CasePaths

@propertyWrapper
public struct PresentationState<State> {
  private var boxedValue: [State]
  fileprivate var isPresented = false

  // TODO: Is this needed?
  //public static var dismissed: Self {
  //  Self(wrappedValue: nil)
  //}
  //
  //public static func presented(_ state: State) -> Self {
  //  Self(wrappedValue: state)
  //}

  @Dependency(\.navigationID) private var navigationID

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
    _read { yield self }
    _modify { yield &self }
  }

  fileprivate var id: NavigationID? {
    self.presentedValue?.id
  }

  fileprivate var presentedValue: (id: NavigationID, state: State)? {
    self.wrappedValue.map { (self.navigationID.append($0), $0) }
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

public protocol _InertPresentationState {}

extension AlertState: _InertPresentationState {}
extension ConfirmationDialogState: _InertPresentationState {}

private func isInert<State>(_ state: State) -> Bool {
  if State.self is _InertPresentationState.Type {
    return true
  } else if let metadata = EnumMetadata(type(of: state)) {
    return metadata.associatedValueType(forTag: metadata.tag(of: state))
      is _InertPresentationState.Type
  } else {
    return false
  }
}

public enum PresentationAction<Action> {
  case dismiss
  case presented(Action)
}

extension PresentationAction: Equatable where Action: Equatable {}
extension PresentationAction: Hashable where Action: Hashable {}

extension PresentationAction: Decodable where Action: Decodable {}
extension PresentationAction: Encodable where Action: Encodable {}

extension ReducerProtocol {
  public func presents<DestinationState, DestinationAction, Destination: ReducerProtocol>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
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

  public func presents<DestinationState, DestinationAction>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _PresentationReducer<Self, EmptyReducer<DestinationState, DestinationAction>> {
    self.presents(
      toPresentationState,
      action: toPresentationAction,
      destination: { EmptyReducer() },
      file: file,
      fileID: fileID,
      line: line
    )
  }
}

public struct _PresentationReducer<
  Base: ReducerProtocol, Destination: ReducerProtocol
>: ReducerProtocol {
  let base: Base
  let toPresentationState: WritableKeyPath<Base.State, PresentationState<Destination.State>>
  let toPresentationAction: CasePath<Base.Action, PresentationAction<Destination.Action>>
  let destination: Destination
  let file: StaticString
  let fileID: StaticString
  let line: UInt

  public func reduce(
    into state: inout Base.State, action: Base.Action
  ) -> EffectTask<Base.Action> {

    let initialPresentationState = state[keyPath: self.toPresentationState]
    let presentationAction = self.toPresentationAction.extract(from: action)

    let destinationEffects: EffectTask<Base.Action>
    let baseEffects: EffectTask<Base.Action>

    switch (initialPresentationState.presentedValue, presentationAction) {
    case (.some, .some(.dismiss)):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
      if initialPresentationState.id != state[keyPath: self.toPresentationState].id {
        runtimeWarn("TODO")
      }
      state[keyPath: self.toPresentationState].wrappedValue = nil

    // TODO: Is the following possible/preferable?
    //if initialPresentationState.id == state[keyPath: self.toPresentationState].id {
    //  state[keyPath: self.toPresentationState].wrappedValue = nil
    //}

    case let (.some((id, destinationState)), .some(.presented(destinationAction))):
      destinationEffects = self.destination
        .dependency(\.dismiss, DismissEffect { Task.cancel(id: DismissID()) })
        .dependency(\.navigationID, id)
        .reduce(
          into: &state[keyPath: self.toPresentationState].wrappedValue!, action: destinationAction
        )
        .map { self.toPresentationAction.embed(.presented($0)) }
        .cancellable(id: id)
      baseEffects = self.base.reduce(into: &state, action: action)
      if isInert(destinationState) {
        state[keyPath: self.toPresentationState].wrappedValue = nil
      }

    case (.none, .none), (.some, .none):
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)

    case (.none, .some):
      runtimeWarn("TODO")
      destinationEffects = .none
      baseEffects = self.base.reduce(into: &state, action: action)
    }

    let presentationChanged =
      initialPresentationState.id != state[keyPath: self.toPresentationState].id

    let dismissEffects: EffectTask<Base.Action>
    if presentationChanged,
      let (id, presentationState) = initialPresentationState.presentedValue,
      !isInert(presentationState)
    {
      dismissEffects = .cancel(id: id)
    } else {
      dismissEffects = .none
    }

    let presentEffects: EffectTask<Base.Action>
    if presentationChanged || !state[keyPath: self.toPresentationState].isPresented,
      let (id, presentationState) = state[keyPath: self.toPresentationState].presentedValue,
      !isInert(presentationState)
    {
      state[keyPath: self.toPresentationState].isPresented = true
      presentEffects = .run { send in
        do {
          try await withDependencies {
            $0.navigationID = id
          } operation: {
            try await withTaskCancellation(id: DismissID()) {
              try await Task.never()
            }
          }
        } catch is CancellationError {
          await send(self.toPresentationAction.embed(.dismiss))
        }
      }
      .cancellable(id: id)
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
}

private struct DismissID: Hashable {}
