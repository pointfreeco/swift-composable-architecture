@dynamicMemberLookup
public struct Wrapped<Value>: Sendable {
  fileprivate let get: @Sendable (Any) -> Value?
  fileprivate let set: @Sendable (inout Any, Value) -> Void

  public init() {
    self.init(get: { $0 }, set: { $0 = $1 })
  }

  public init<Root>(
    get: @escaping @Sendable (Root) -> Value?,
    set: @escaping @Sendable (inout Root, Value) -> Void
  ) {
    self.get = { get($0 as! Root) }
    self.set = {
      var root = $0 as! Root
      set(&root, $1)
      $0 = root
    }
  }

  public subscript<Member>(
    dynamicMember keyPath: WritableKeyPath<Value, Member>
  ) -> Wrapped<Member> {
    Wrapped<Member>(
      get: { self.get($0)?[keyPath: keyPath] },
      set: { root, member in
        guard var value = self.get(root)?[keyPath: keyPath] as! Value? else { return }
        value[keyPath: keyPath] = member
        self.set(&root, value)
      }
    )
  }

  public subscript<Member>(
    dynamicMember keyPath: CaseKeyPath<Value, Member>
  ) -> Wrapped<Member>
  where Value: CasePathable {
    Wrapped<Member>(
      get: { self.get($0)?[case: keyPath] },
      set: { root, member in
        guard var value = self.get(root)?[case: keyPath] as! Value? else { return }
        value[case: keyPath] = member
        self.set(&root, value)
      }
    )
  }
}

public typealias OptionalPath<Root, Value> = KeyPath<Wrapped<Root>, Wrapped<Value>>

public struct Scope2<State, Action: CasePathable, Child: Reducer>: Reducer {
  let toChildState: OptionalPath<State, Child.State>
  let toChildAction: CaseKeyPath<Action, Child.Action>
  let child: Child

  public init<ChildState, ChildAction>(
    state toChildState: OptionalPath<State, ChildState>,
    action toChildAction: CaseKeyPath<Action, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child
  ) where Child.State == ChildState, Child.Action == ChildAction {
    self.toChildState = toChildState
    self.toChildAction = toChildAction
    self.child = child()
  }

  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    let wrapped = Wrapped<State>()[keyPath: toChildState]
    guard var childState = wrapped.get(state) else { return .none }
    guard let childAction = action[case: toChildAction] else { return .none }
    let childEffects = child.reduce(into: &childState, action: childAction)
    var anyState = state as Any
    wrapped.set(&anyState, childState)
    state = anyState as! State
    return childEffects.map(toChildAction.callAsFunction)
  }
}

@Reducer
struct Child {
}

@Reducer
struct Parent {
  @CasePathable
  enum Destination {
    case child(Child.State)
  }

  @ObservableState
  struct State {
    var destination: Destination?
  }

  enum Action {
    case child(Child.Action)
  }

  var body: some ReducerOf<Self> {
    Scope2(state: \.destination.child, action: \.child) {
      Child()
    }
  }
}
