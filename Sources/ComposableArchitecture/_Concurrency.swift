//public enum TaskResult<Success> {
//  case success(Success)
//  case failure(any Error)
//
//  public init(catching body: () async throws -> Success) async {
//    do {
//      self = .success(try await body())
//    } catch {
//      self = .failure(error)
//    }
//  }
//}
//
//extension TaskResult: Equatable where Success: Equatable {
//  public static func == (lhs: Self, rhs: Self) -> Bool {
//    switch (lhs, rhs) {
//    case let (.success(lhs), .success(rhs)):
//      return lhs == rhs
//    case let (.failure(lhs as NSError), .failure(rhs as NSError)):
//      return lhs == rhs
//    default:
//      return false
//    }
//  }
//}
//
//extension TaskResult: Hashable where Success: Hashable {
//  public func hash(into hasher: inout Hasher) {
//    switch self {
//    case let .success(success):
//      hasher.combine(success)
//    case let .failure(failure):
//      hasher.combine(failure as NSError)
//    }
//  }
//}
//
//public struct _Effect<Element>: AsyncSequence {
//  private let _makeAsyncIterator: () -> AsyncIterator
//
//  fileprivate init(makeAsyncIterator: @escaping () -> AsyncIterator) {
//    self._makeAsyncIterator = makeAsyncIterator
//  }
//
//  public func makeAsyncIterator() -> AsyncIterator {
//    self._makeAsyncIterator()
//  }
//
//  public struct AsyncIterator: AsyncIteratorProtocol {
//    private let _next: () async -> Element?
//
//    fileprivate init(next: @escaping () async -> Element?) {
//      self._next = next
//    }
//
//    public func next() async -> Element? {
//      await self._next()
//    }
//  }
//}
//
//extension _Effect {
//  public static func task(
//    priority: TaskPriority? = nil, operation: @escaping () async -> Element
//  ) -> Self {
//    Self {
//      var didExecute = false  // FIXME: Better way to track this?
//      return AsyncIterator {
//        guard !didExecute else { return nil }
//        didExecute = true
//        return await Task(priority: priority) { await operation() }.value
//      }
//    }
//  }
//
////  return someAsyncSequence
////    .map(MyAction.case)
////    .eraseToEffect()
////
////  return someAsyncSequence
////    .map(MyAction.case)
////    .catchToEffect()
////
////  return .stream {
////    for await x in someAsyncSequence.map(MyAction.case) {
////      $0.yield(x)
////    }
////  }
//
//  public static func stream(
//    _ build: @escaping (AsyncStream<Element>.Continuation) -> Void
//  ) -> Self {
//    Self {
//      let stream = AsyncStream { build($0) }
//      var iterator = stream.makeAsyncIterator()
//      return AsyncIterator { await iterator.next() }
//    }
//  }
//
//  public static var none: Self {
//    Self {
//      AsyncIterator { nil }
//    }
//  }
//
//  public init<S: AsyncSequence>(_ sequence: S) where Element == TaskResult<S.Element> {
//    self.init {
//      var iterator = sequence.makeAsyncIterator()
//      return AsyncIterator {
//        do {
//          return try await iterator.next().map(TaskResult.success)
//        } catch {
//          return .failure(error)
//        }
//      }
//    }
//  }
//}
//
//extension AsyncSequence {
//  public func catchToEffect() -> _Effect<TaskResult<Element>> {
//    .init(self)
//  }
//}
//
//public struct _Reducer<State, Action, Environment> {
//  let reducer: (inout State, Action, Environment) -> _Effect<Action>
//
//  public func callAsFunction(
//    into state: inout State, action: Action, environment: Environment
//  ) -> _Effect<Action> {
//    self.reducer(&state, action, environment)
//  }
//}
//
//public class _Store<State, Action> {
//  private var state: State
//  private let reducer: (inout State, Action) -> _Effect<Action>
//
//  public init<Environment>(
//    initialState: State,
//    reducer reduce: _Reducer<State, Action, Environment>,
//    environment: Environment
//  ) {
//    self.state = initialState
//    self.reducer = { reduce(into: &$0, action: $1, environment: environment) }
//  }
//
//  func send(_ action: Action) async {
//    for await action in self.reducer(&self.state, action) {
//      await self.send(action)
//    }
//  }
//}
