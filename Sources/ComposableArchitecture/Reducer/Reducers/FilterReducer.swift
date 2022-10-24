extension ReducerProtocol {
#if swift(>=5.7)
  @inlinable
  public func filter<WrappedState, WrappedAction>(
    _ toWrappedState: WritableKeyPath<State, WrappedState>,
    action toWrappedAction: CasePath<Action, WrappedAction>,
    @ReducerBuilder<WrappedState, WrappedAction> then wrapped: () -> some ReducerProtocol<WrappedState, WrappedAction>,
    behaviour: FilterBehaviour = .filter,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> some ReducerProtocol<State, Action> {
    _Filter(
      parent: self,
      child: wrapped(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      behaviour: behaviour,
      file: file,
      fileID: fileID,
      line: line
    )
  }
#else
  @inlinable
  public func filter<Case: ReducerProtocol>(
    _ toCaseState: CasePath<State, Case.State>,
    action toCaseAction: CasePath<Action, Case.Action>,
    @ReducerBuilderOf<Case> then case: () -> Case,
    behaviour: FilterBehaviour = .filter,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _Filter<Self, Case> {
    .init(
      parent: self,
      child: `case`(),
      toChildState: toCaseState,
      toChildAction: toCaseAction,
      behaviour: behaviour,
      file: file,
      fileID: fileID,
      line: line
    )
  }
#endif
}

public enum FilterBehaviour {
  case filter // if filter reducer return .none it let parent reducer do it work
  case block // if filter reducer return .none it stop the let parent reducer from doing it's work
}

extension EffectPublisher.Operation {
  public var isNone: Bool {
    switch self {
    case .none:
      return true
    default:
      return false
    }
  }
}

public struct _Filter<Parent: ReducerProtocol, Child: ReducerProtocol>: ReducerProtocol {
  @usableFromInline
  let parent: Parent
  
  @usableFromInline
  let child: Child
  
  @usableFromInline
  let toChildState: WritableKeyPath<Parent.State, Child.State>
  
  @usableFromInline
  let toChildAction: CasePath<Parent.Action, Child.Action>
  
  @usableFromInline
  let file: StaticString
  
  @usableFromInline
  let fileID: StaticString
  
  @usableFromInline
  let line: UInt
  
  @usableFromInline
  let behaviour: FilterBehaviour
  
  @usableFromInline
  init(
    parent: Parent,
    child: Child,
    toChildState: WritableKeyPath<Parent.State, Child.State>,
    toChildAction: CasePath<Parent.Action, Child.Action>,
    behaviour: FilterBehaviour = .filter,
    file: StaticString,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.child = child
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.behaviour = behaviour
    self.file = file
    self.fileID = fileID
    self.line = line
  }
  
  @inlinable
  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    let effect = self.reduceChild(into: &state, action: action)
    let shouldBlock = self.behaviour == .block
    switch (shouldBlock, effect.operation.isNone) {
    case (true, true):
      return effect
    case (true, false):
      return effect
    case (false, true):
      return effect.merge(with: self.parent.reduce(into: &state, action: action))
    case (false, false):
      return effect
    }
  }
  
  @inlinable
  func reduceChild(
    into state: inout Parent.State, action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    
    guard let childAction = self.toChildAction.extract(from: action)
    else { return .none }
    return self.child.reduce(into: &state[keyPath: self.toChildState], action: childAction)
      .map(self.toChildAction.embed)
  }
}
