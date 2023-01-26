//public struct NavigationID: DependencyKey, Hashable {
//  public static let liveValue = NavigationID(path: .root)
//  public static let testValue = NavigationID(path: .root)
//
//  private let path: Path
//
//  fileprivate func append<Value>(_ value: Value) -> Self {
//    Self(path: .destination(presenter: self, presented: Path.ComponentID(value)))
//  }
//
//  fileprivate enum Path: Hashable {
//    case root
//    indirect case destination(presenter: NavigationID, presented: ComponentID)
//
//    fileprivate struct ComponentID: Hashable {
//      var objectIdentifier: ObjectIdentifier
//      var tag: UInt32?
//      var id: AnyHashable?
//
//      init<Value>(_ value: Value) {
//        func id(_ identifiable: some Identifiable) -> AnyHashable {
//          identifiable.id
//        }
//
//        self.objectIdentifier = ObjectIdentifier(Value.self)
//        self.tag = enumTag(value)
//        if let value = value as? any Identifiable {
//          self.id = id(value)
//        }
//        // TODO: If identifiable fails but enum tag exists, further extract value and use its identity
//      }
//    }
//  }
//}
//
//extension DependencyValues {
//  var navigationID: NavigationID {
//    get { self[NavigationID.self] }
//    set { self[NavigationID.self] = newValue }
//  }
//}
//
//@propertyWrapper
//public struct PresentationState<State> {
//  private var boxedValue: [State]
//
//  @Dependency(\.navigationID) var navigationID
//
//  public init(wrappedValue: State?) {
//    self.boxedValue = wrappedValue.map { [$0] } ?? []
//  }
//
//  public var wrappedValue: State? {
//    _read { yield self.boxedValue.first }
//    _modify {
//      var wrappedValue = self.boxedValue.first
//      yield &wrappedValue
//      switch (wrappedValue, self.boxedValue.isEmpty) {
//      case let (.some(state), true):
//        self.boxedValue.append(state)
//      case let (.some(state), false):
//        self.boxedValue[0] = state
//      case (nil, true):
//        break
//      case (nil, false):
//        self.boxedValue.removeFirst()
//      }
//    }
//    // TODO: Measure if `_read` and `_modify` help here.
//    // TODO: Determine if `set` is needed in addition.
//  }
//
//  public init(projectedValue: Self) {
//    self = projectedValue
//  }
//
//  public var projectedValue: Self {
//    _read { yield self }
//    _modify { yield &self }
//    // TODO: Measure if `_read` and `_modify` help here.
//  }
//
//  public var identifiedValue: (id: NavigationID, state: State)? {
//    self.wrappedValue.map { (self.navigationID.append($0), $0) }
//  }
//}
//
//extension PresentationState: Equatable where State: Equatable {
//  public static func == (lhs: Self, rhs: Self) -> Bool {
//    lhs.wrappedValue == rhs.wrappedValue
//  }
//}
//extension PresentationState: Hashable where State: Hashable {
//  public func hash(into hasher: inout Hasher) {
//    self.wrappedValue.hash(into: &hasher)
//  }
//}
//
//public enum PresentationAction<Action> {
//  case dismiss
//  case presented(Action)
//}
//
//extension PresentationAction: Equatable where Action: Equatable {}
//extension PresentationAction: Hashable where Action: Hashable {}
//
//extension ReducerProtocol {
//  public func presentationDestination<
//    DestinationState, DestinationAction, Destination: ReducerProtocol
//  >(
//    state toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
//    action toPresentationAction: CasePath<Action, PresentationAction<DestinationAction>>,
//    @ReducerBuilder<DestinationState, DestinationAction> _ destination: () -> Destination,
//    file: StaticString = #file,
//    fileID: StaticString = #fileID,
//    line: UInt = #line
//  ) -> _PresentationDestinationReducer<Self, Destination>
//  where DestinationState == Destination.State, DestinationAction == Destination.Action {
//    _PresentationDestinationReducer(
//      presenter: self,
//      presented: destination(),
//      toPresentationState: toPresentationState,
//      toPresentationAction: toPresentationAction,
//      file: file,
//      fileID: fileID,
//      line: line
//    )
//  }
//}
//
//public struct _PresentationDestinationReducer<
//  Presenter: ReducerProtocol, Presented: ReducerProtocol
//>: ReducerProtocol {
//  let presenter: Presenter
//  let presented: Presented
//  let toPresentationState: WritableKeyPath<Presenter.State, PresentationState<Presented.State>>
//  let toPresentationAction: CasePath<Presenter.Action, PresentationAction<Presented.Action>>
//  let file: StaticString
//  let fileID: StaticString
//  let line: UInt
//
//  public func reduce(
//    into state: inout Presenter.State, action: Presenter.Action
//  ) -> EffectTask<Presenter.Action> {
//    let presentationState = state[keyPath: self.toPresentationState]
//    let presentationAction = self.toPresentationAction.extract(from: action)
//    var effects: EffectTask<Presenter.Action> = .none
//
//    if case let .some(.presented(presentedAction)) = presentationAction {
//      switch presentationState.identifiedValue {
//      case .some((let id, var presentedState)):
//        defer { state[keyPath: self.toPresentationState].wrappedValue = presentedState }
//        effects = effects.merge(
//          with: self.presented
//            .dependency(\.navigationID, id)
//            .reduce(into: &presentedState, action: presentedAction)
//            .map { self.toPresentationAction.embed(.presented($0)) }
//            .cancellable(id: id)
//        )
//      case .none:
//        runtimeWarn("Presented action sent to dismissed state")
//      }
//    }
//
//    effects = effects.merge(
//      with: self.presenter.reduce(into: &state, action: action)
//    )
//
//    if case .some(.dismiss) = presentationAction {
//      if state[keyPath: self.toPresentationState].wrappedValue == nil {
//        runtimeWarn("Dismiss action sent to dismissed state")
//      } else {
//        state[keyPath: self.toPresentationState].wrappedValue = nil
//      }
//    }
//
//    if
//      let (id, _) = presentationState.identifiedValue,
//      state[keyPath: self.toPresentationState].identifiedValue?.id != id
//    {
//      effects = effects.merge(
//        with: .cancel(id: id)
//      )
//    }
//
//    // TODO:
//    // if
//    //   state[keyPath: self.toPresentationState].wrappedValue.map(_isDialogState) == true,
//    //   case .some(.presented) = presentationAction
//    // {
//    //   state[keyPath: self.toPresentationState].wrappedValue = nil
//    // }
//
//    return effects
//  }
//}
