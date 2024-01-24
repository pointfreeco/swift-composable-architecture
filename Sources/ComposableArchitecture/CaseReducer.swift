
protocol CaseReducer<State, Action> {
  associatedtype State: CaseReducerState where State.Reducer == Self
  associatedtype Action
  associatedtype Body: Reducer<State, Action>

  @ReducerBuilder<State, Action>
  static var body: Body { get }
}

protocol CaseReducerState {
  associatedtype Reducer: CaseReducer where Reducer.State == Self
}

@Reducer
struct Foo {
  struct State: Equatable {}
  enum Action {}
  let body = EmptyReducer<State, Action>()
}

enum Destination: CaseReducer {
  case foo(Foo)

  @CasePathable
  @dynamicMemberLookup
  @ObservableState
  enum State: CaseReducerState, Equatable {
    typealias Reducer = Destination
    case foo(Foo.State)
  }
  @CasePathable
  enum Action {
    case foo(Foo.Action)
  }
  static var body: some Reducer<State, Action> {
    Scope(state: \.foo, action: \.foo) {
      Foo()
    }
  }
}

extension Reducer {
  func ifLet<ChildState: CaseReducerState, ChildAction>(
    _ state: WritableKeyPath<State, PresentationState<ChildState>>,
    action: CaseKeyPath<Action, PresentationAction<ChildAction>>
  ) -> some ReducerOf<Self> where ChildState.Reducer.Action == ChildAction {
    self.ifLet(state, action: action) {
      ChildState.Reducer.body
    }
  }
}
