public struct GroupReducer<Upstream: ReducerProtocol>: ReducerProtocol {
  public let upstream: Upstream
  public init(@ReducerBuilderOf<Upstream> upstream: () -> Upstream) {
    self.upstream = upstream()
  }
  public func reduce(
    into state: inout Upstream.State,
    action: Upstream.Action
  ) -> Effect<Upstream.Action, Never> {
    self.upstream.reduce(into: &state, action: action)
  }
}

struct Foo: ReducerProtocol {
  var body: some ReducerProtocol<Int, Void> {
    EmptyReducer()
  }
}

// NB: bug report
// TODO: name? GroupReducer, ReducerGroup, CombineReducers, etc...
func _GroupReducer<State, Action>(
  @ReducerBuilder<State, Action> build: () -> some ReducerProtocol<State, Action>
) -> some ReducerProtocol<State, Action> {
  build()
}

struct Bar: ReducerProtocol {
  var body: some ReducerProtocol<Int, Void> {
    _GroupReducer {
      Foo()
      Reduce { state, action in
        return .none
      }
    }
  }
}

//let t = GroupReducer {
//  Foo()
//  Reduce { state, action in
//    return .none
//  }
//}
