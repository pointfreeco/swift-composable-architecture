#if swift(>=5.9)
  @_spi(Internals) import ComposableArchitecture
  import XCTest

  final class StackReducerTests: BaseTCATestCase {
    @MainActor
    func testStackStateSubscriptCase() {
      enum Element: Equatable {
        case int(Int)
        case text(String)
      }

      var stack = StackState<Element>([.int(42)])
      stack[id: 0, case: /Element.int]? += 1
      XCTAssertEqual(stack[id: 0], .int(43))

      stack[id: 0, case: /Element.int] = nil
      XCTAssertTrue(stack.isEmpty)
    }

    @MainActor
    func testStackStateSubscriptCase_Unexpected() {
      enum Element: Equatable {
        case int(Int)
        case text(String)
      }

      var stack = StackState<Element>([.int(42)])

      XCTExpectFailure {
        stack[id: 0, case: /Element.text]?.append("!")
      } issueMatcher: {
        $0.compactDescription == """
          Can't modify unrelated case "int"
          """
      }

      XCTExpectFailure {
        stack[id: 0, case: /Element.text] = nil
      } issueMatcher: {
        $0.compactDescription == """
          Can't modify unrelated case "int"
          """
      }

      XCTAssertEqual(Array(stack), [.int(42)])
    }

    @MainActor
    func testCustomDebugStringConvertible() {
      @Dependency(\.stackElementID) var stackElementID
      XCTAssertEqual(stackElementID.peek().generation, 0)
      XCTAssertEqual(stackElementID.next().customDumpDescription, "#0")
      XCTAssertEqual(stackElementID.peek().generation, 1)
      XCTAssertEqual(stackElementID.next().customDumpDescription, "#1")

      withDependencies {
        $0.context = .live
      } operation: {
        XCTAssertEqual(stackElementID.next().customDumpDescription, "#0")
        XCTAssertEqual(stackElementID.next().customDumpDescription, "#1")
      }
    }

    @MainActor
    func testPresent() async {
      struct Child: Reducer {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case decrementButtonTapped
          case incrementButtonTapped
        }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .decrementButtonTapped:
              state.count -= 1
              return .none
            case .incrementButtonTapped:
              state.count += 1
              return .none
            }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case children(StackActionOf<Child>)
          case pushChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .pushChild:
              state.children.append(Child.State())
              return .none
            }
          }
          .forEach(\.children, action: /Action.children) {
            Child()
          }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.pushChild) {
        $0.children.append(Child.State())
      }
    }

    @MainActor
    func testDismissFromParent() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {
          case onAppear
        }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .onAppear:
              return .run { _ in
                try await Task.never()
              }
            }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case children(StackActionOf<Child>)
          case popChild
          case pushChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .popChild:
              state.children.removeLast()
              return .none
            case .pushChild:
              state.children.append(Child.State())
              return .none
            }
          }
          .forEach(\.children, action: /Action.children) {
            Child()
          }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.pushChild) {
        $0.children.append(Child.State())
      }
      await store.send(.children(.element(id: 0, action: .onAppear)))
      await store.send(.popChild) {
        $0.children.removeLast()
      }
    }

    @MainActor
    func testDismissFromChild() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {
          case closeButtonTapped
          case onAppear
        }
        @Dependency(\.dismiss) var dismiss
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .closeButtonTapped:
              return .run { _ in
                await self.dismiss()
              }
            case .onAppear:
              return .run { _ in
                try await Task.never()
              }
            }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case children(StackActionOf<Child>)
          case pushChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .pushChild:
              state.children.append(Child.State())
              return .none
            }
          }
          .forEach(\.children, action: /Action.children) {
            Child()
          }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.pushChild) {
        $0.children.append(Child.State())
      }
      await store.send(.children(.element(id: 0, action: .onAppear)))
      await store.send(.children(.element(id: 0, action: .closeButtonTapped)))
      await store.receive(.children(.popFrom(id: 0))) {
        $0.children.removeLast()
      }
    }

    @MainActor
    func testDismissReceiveWrongAction() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable { case tap }
        @Dependency(\.dismiss) var dismiss
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            .run { _ in await self.dismiss() }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case children(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }.forEach(\.children, action: /Action.children) { Child() }
        }
      }

      let store = TestStore(initialState: Parent.State(children: StackState([Child.State()]))) {
        Parent()
      }

      XCTExpectFailure {
        $0.compactDescription == """
          Received unexpected action: …

                StackReducerTests.Parent.Action.children(
              −   .popFrom(id: #1)
              +   .popFrom(id: #0)
                )

          (Expected: −, Received: +)
          """
      }

      await store.send(.children(.element(id: 0, action: .tap)))
      await store.receive(.children(.popFrom(id: 1))) {
        $0.children = StackState()
      }
    }

    @MainActor
    func testDismissFromIntermediateChild() async {
      struct Child: Reducer {
        struct State: Equatable { var count = 0 }
        enum Action: Equatable {
          case onAppear
        }
        @Dependency(\.dismiss) var dismiss
        @Dependency(\.mainQueue) var mainQueue
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .onAppear:
              return .run { [count = state.count] _ in
                try await self.mainQueue.sleep(for: .seconds(count))
                await self.dismiss()
              }
            }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }
            .forEach(\.children, action: /Action.child) { Child() }
        }
      }

      let mainQueue = DispatchQueue.test
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.mainQueue = mainQueue.eraseToAnyScheduler()
      }

      await store.send(.child(.push(id: 0, state: Child.State(count: 2)))) {
        $0.children[id: 0] = Child.State(count: 2)
      }
      await store.send(.child(.element(id: 0, action: .onAppear)))

      await store.send(.child(.push(id: 1, state: Child.State(count: 1)))) {
        $0.children[id: 1] = Child.State(count: 1)
      }
      await store.send(.child(.element(id: 1, action: .onAppear)))

      await store.send(.child(.push(id: 2, state: Child.State(count: 2)))) {
        $0.children[id: 2] = Child.State(count: 2)
      }
      await store.send(.child(.element(id: 2, action: .onAppear)))

      await mainQueue.advance(by: .seconds(1))
      await store.receive(.child(.popFrom(id: 1))) {
        $0.children.removeLast(2)
      }
      await store.send(.child(.popFrom(id: 0))) {
        $0.children = StackState()
      }
    }

    @MainActor
    func testDismissFromDeepLinkedChild() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {
          case closeButtonTapped
        }
        @Dependency(\.dismiss) var dismiss
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .closeButtonTapped:
              return .run { _ in
                await self.dismiss()
              }
            }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case children(StackActionOf<Child>)
          case pushChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .pushChild:
              state.children.append(Child.State())
              return .none
            }
          }
          .forEach(\.children, action: /Action.children) {
            Child()
          }
        }
      }

      var children = StackState<Child.State>()
      children.append(Child.State())
      let store = TestStore(initialState: Parent.State(children: children)) {
        Parent()
      }

      await store.send(.children(.element(id: 0, action: .closeButtonTapped)))
      await store.receive(.children(.popFrom(id: 0))) {
        $0.children.removeAll()
      }
    }

    @MainActor
    func testEnumChild() async {
      struct Child: Reducer {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case closeButtonTapped
          case incrementButtonTapped
          case onAppear
        }
        @Dependency(\.dismiss) var dismiss
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .closeButtonTapped:
              return .run { _ in
                await self.dismiss()
              }
            case .incrementButtonTapped:
              state.count += 1
              return .none
            case .onAppear:
              return .run { _ in
                try await Task.never()
              }
            }
          }
        }
      }
      struct Path: Reducer {
        enum State: Equatable {
          case child1(Child.State)
          case child2(Child.State)
        }
        enum Action: Equatable {
          case child1(Child.Action)
          case child2(Child.Action)
        }
        var body: some ReducerOf<Self> {
          Scope(state: /State.child1, action: /Action.child1) {
            Child()
          }
          Scope(state: /State.child2, action: /Action.child2) {
            Child()
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var path = StackState<Path.State>()
        }
        enum Action: Equatable {
          case path(StackActionOf<Path>)
          case pushChild1
          case pushChild2
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .path:
              return .none
            case .pushChild1:
              state.path.append(.child1(Child.State()))
              return .none
            case .pushChild2:
              state.path.append(.child2(Child.State()))
              return .none
            }
          }
          .forEach(\.path, action: /Action.path) {
            Path()
          }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }
      await store.send(.pushChild1) {
        $0.path.append(.child1(Child.State()))
      }
      await store.send(.path(.element(id: 0, action: .child1(.onAppear))))
      await store.send(.pushChild2) {
        $0.path.append(.child2(Child.State()))
      }
      await store.send(.path(.element(id: 1, action: .child2(.onAppear))))
      await store.send(.path(.popFrom(id: 0))) {
        $0.path.removeAll()
      }
    }

    @MainActor
    func testParentDismiss() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action { case tap }
        @Dependency(\.dismiss) var dismiss
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            .run { _ in try await Task.never() }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var path = StackState<Child.State>()
        }
        enum Action {
          case path(StackActionOf<Child>)
          case popToRoot
          case pushChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .path:
              return .none
            case .popToRoot:
              state.path.removeAll()
              return .none
            case .pushChild:
              state.path.append(Child.State())
              return .none
            }
          }
          .forEach(\.path, action: /Action.path) {
            Child()
          }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }
      await store.send(.pushChild) {
        $0.path.append(Child.State())
      }
      await store.send(.path(.element(id: 0, action: .tap)))
      await store.send(.pushChild) {
        $0.path.append(Child.State())
      }
      await store.send(.path(.element(id: 1, action: .tap)))
      await store.send(.popToRoot) {
        $0.path.removeAll()
      }
    }

    enum TestSiblingCannotCancel {
      @Reducer
      struct Child {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case cancel
          case response(Int)
          case tap
        }
        @Dependency(\.mainQueue) var mainQueue
        enum CancelID: Hashable { case cancel }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .cancel:
              return .cancel(id: CancelID.cancel)
            case let .response(value):
              state.count = value
              return .none
            case .tap:
              return .run { send in
                try await self.mainQueue.sleep(for: .seconds(1))
                await send(.response(42))
              }
              .cancellable(id: CancelID.cancel)
            }
          }
        }
      }
      @Reducer
      struct Path {
        enum State: Equatable {
          case child1(Child.State)
          case child2(Child.State)
        }
        enum Action: Equatable {
          case child1(Child.Action)
          case child2(Child.Action)
        }
        var body: some ReducerOf<Self> {
          Scope(state: \.child1, action: \.child1) { Child() }
          Scope(state: \.child2, action: \.child2) { Child() }
        }
      }
      @Reducer
      struct Parent {
        struct State: Equatable {
          var path = StackState<Path.State>()
        }
        enum Action: Equatable {
          case path(StackActionOf<Path>)
          case pushChild1
          case pushChild2
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .path:
              return .none
            case .pushChild1:
              state.path.append(.child1(Child.State()))
              return .none
            case .pushChild2:
              state.path.append(.child2(Child.State()))
              return .none
            }
          }
          .forEach(\.path, action: \.path) {
            Path()
          }
        }
      }
    }
    @MainActor
    func testSiblingCannotCancel() async {
      var path = StackState<TestSiblingCannotCancel.Path.State>()
      path.append(.child1(TestSiblingCannotCancel.Child.State()))
      path.append(.child2(TestSiblingCannotCancel.Child.State()))
      let mainQueue = DispatchQueue.test
      let store = TestStore(initialState: TestSiblingCannotCancel.Parent.State(path: path)) {
        TestSiblingCannotCancel.Parent()
      } withDependencies: {
        $0.mainQueue = mainQueue.eraseToAnyScheduler()
      }

      await store.send(.path(.element(id: 0, action: .child1(.tap))))
      await store.send(.path(.element(id: 1, action: .child2(.tap))))
      await store.send(.path(.element(id: 0, action: .child1(.cancel))))
      await mainQueue.advance(by: .seconds(1))
      await store.receive(.path(.element(id: 1, action: .child2(.response(42))))) {
        $0.path[id: 1, case: \.child2]?.count = 42
      }

      await store.send(.path(.element(id: 0, action: .child1(.tap))))
      await store.send(.path(.element(id: 1, action: .child2(.tap))))
      await store.send(.path(.element(id: 1, action: .child2(.cancel))))
      await mainQueue.advance(by: .seconds(1))
      await store.receive(.path(.element(id: 0, action: .child1(.response(42))))) {
        $0.path[id: 0, case: \.child1]?.count = 42
      }
    }

    enum TestFirstChildWhileEffectInFlight_DeliversToCorrectID {
      @Reducer
      struct Child {
        let id: Int
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case response(Int)
          case tap
        }
        @Dependency(\.mainQueue) var mainQueue
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case let .response(value):
              state.count += value
              return .none
            case .tap:
              return .run { send in
                try await self.mainQueue.sleep(for: .seconds(self.id))
                await send(.response(self.id))
              }
            }
          }
        }
      }
      @Reducer
      struct Path {
        enum State: Equatable {
          case child1(Child.State)
          case child2(Child.State)
        }
        enum Action: Equatable {
          case child1(Child.Action)
          case child2(Child.Action)
        }
        var body: some ReducerOf<Self> {
          Scope(state: \.child1, action: \.child1) { Child(id: 1) }
          Scope(state: \.child2, action: \.child2) { Child(id: 2) }
        }
      }
      @Reducer
      struct Parent {
        struct State: Equatable {
          var path = StackState<Path.State>()
        }
        enum Action: Equatable {
          case path(StackActionOf<Path>)
          case popAll
          case popFirst
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .path:
              return .none
            case .popAll:
              state.path = StackState()
              return .none
            case .popFirst:
              state.path[id: state.path.ids[0]] = nil
              return .none
            }
          }
          .forEach(\.path, action: \.path) {
            Path()
          }
        }
      }
    }
    @MainActor
    func testFirstChildWhileEffectInFlight_DeliversToCorrectID() async {
      let mainQueue = DispatchQueue.test
      let store = TestStore(
        initialState: TestFirstChildWhileEffectInFlight_DeliversToCorrectID.Parent.State(
          path: StackState([
            .child1(TestFirstChildWhileEffectInFlight_DeliversToCorrectID.Child.State()),
            .child2(TestFirstChildWhileEffectInFlight_DeliversToCorrectID.Child.State()),
          ])
        )
      ) {
        TestFirstChildWhileEffectInFlight_DeliversToCorrectID.Parent()
      } withDependencies: {
        $0.mainQueue = mainQueue.eraseToAnyScheduler()
      }

      await store.send(.path(.element(id: 0, action: .child1(.tap))))
      await store.send(.path(.element(id: 1, action: .child2(.tap))))
      await mainQueue.advance(by: .seconds(1))
      await store.receive(.path(.element(id: 0, action: .child1(.response(1))))) {
        $0.path[id: 0, case: \.child1]?.count = 1
      }
      await mainQueue.advance(by: .seconds(1))
      await store.receive(.path(.element(id: 1, action: .child2(.response(2))))) {
        $0.path[id: 1, case: \.child2]?.count = 2
      }

      await store.send(.path(.element(id: 0, action: .child1(.tap))))
      await store.send(.path(.element(id: 1, action: .child2(.tap))))
      await store.send(.popFirst) {
        $0.path[id: 0] = nil
      }
      await mainQueue.advance(by: .seconds(2))
      await store.receive(.path(.element(id: 1, action: .child2(.response(2))))) {
        $0.path[id: 1, case: \.child2]?.count = 4
      }
      await store.send(.popFirst) {
        $0.path[id: 1] = nil
      }
    }

    @MainActor
    func testSendActionWithIDThatDoesNotExist() async {
      struct Parent: Reducer {
        struct State: Equatable {
          var path = StackState<Int>()
        }
        enum Action {
          case path(StackAction<Int, Void>)
        }
        var body: some ReducerOf<Self> {
          EmptyReducer()
            .forEach(\.path, action: /Action.path) {}
        }
      }
      let line = #line - 3

      XCTExpectFailure {
        $0.compactDescription == """
          A "forEach" at "ComposableArchitectureTests/StackReducerTests.swift:\(line)" received an \
          action for a missing element. …

            Action:
              ()

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer removed an element with this ID before this reducer ran. This reducer \
          must run before any other reducer removes an element, which ensures that element \
          reducers can handle their actions while their state is still available.

          • An in-flight effect emitted this action when state contained no element at this ID. \
          While it may be perfectly reasonable to ignore this action, consider canceling the \
          associated effect before an element is removed, especially if it is a long-living effect.

          • This action was sent to the store while its state contained no element at this ID. To \
          fix this make sure that actions for this reducer can only be sent from a view store when \
          its state contains an element at this id. In SwiftUI applications, use \
          "NavigationStack.init(path:)" with a binding to a store.
          """
      }

      var path = StackState<Int>()
      path.append(1)
      let store = TestStore(initialState: Parent.State(path: path)) {
        Parent()
      }
      await store.send(.path(.element(id: 999, action: ())))
    }

    @MainActor
    func testPopIDThatDoesNotExist() async {
      struct Parent: Reducer {
        struct State: Equatable {
          var path = StackState<Int>()
        }
        enum Action {
          case path(StackAction<Int, Void>)
        }
        var body: some ReducerOf<Self> {
          EmptyReducer()
            .forEach(\.path, action: /Action.path) {}
        }
      }
      let line = #line - 3

      XCTExpectFailure {
        $0.compactDescription == """
          A "forEach" at "ComposableArchitectureTests/StackReducerTests.swift:\(line)" received a \
          "popFrom" action for a missing element. …

            ID:
              #999
            Path IDs:
              [#0]
          """
      }

      let store = TestStore(initialState: Parent.State(path: StackState<Int>([1]))) {
        Parent()
      }
      await store.send(.path(.popFrom(id: 999)))
    }

    @MainActor
    func testChildWithInFlightEffect() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action { case tap }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            .run { _ in try await Task.never() }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var path = StackState<Child.State>()
        }
        enum Action {
          case path(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          EmptyReducer()
            .forEach(\.path, action: /Action.path) { Child() }
        }
      }

      var path = StackState<Child.State>()
      path.append(Child.State())
      let store = TestStore(initialState: Parent.State(path: path)) {
        Parent()
      }
      let line = #line
      await store.send(.path(.element(id: 0, action: .tap)))

      XCTExpectFailure {
        $0.sourceCodeContext.location?.fileURL.absoluteString.contains("BaseTCATestCase") == true
          || $0.sourceCodeContext.location?.lineNumber == line + 1
            && $0.compactDescription == """
              An effect returned for this action is still running. It must complete before the end \
              of the test. …

              To fix, inspect any effects the reducer returns for this action and ensure that all \
              of them complete by the end of the test. There are a few reasons why an effect may \
              not have completed:

              • If using async/await in your effect, it may need a little bit of time to properly \
              finish. To fix you can simply perform "await store.finish()" at the end of your test.

              • If an effect uses a clock/scheduler (via "receive(on:)", "delay", "debounce", \
              etc.), make sure that you wait enough time for it to perform the effect. If you are \
              using a test clock/scheduler, advance it so that the effects may complete, or \
              consider using an immediate clock/scheduler to immediately perform the effect instead.

              • If you are returning a long-living effect (timers, notifications, subjects, etc.), \
              then make sure those effects are torn down by marking the effect ".cancellable" and \
              returning a corresponding cancellation effect ("Effect.cancel") from another action, \
              or, if your effect is driven by a Combine subject, send it a completion.
              """
      }
    }

    @MainActor
    func testMultipleChildEffects() async {
      struct Child: Reducer {
        struct State: Equatable { var count = 0 }
        enum Action: Equatable {
          case tap
          case response(Int)
        }
        @Dependency(\.mainQueue) var mainQueue
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .tap:
              return .run { [count = state.count] send in
                try await self.mainQueue.sleep(for: .seconds(count))
                await send(.response(42))
              }
            case let .response(value):
              state.count = value
              return .none
            }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children: StackState<Child.State>
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }
            .forEach(\.children, action: /Action.child) { Child() }
        }
      }

      let mainQueue = DispatchQueue.test
      let store = TestStore(
        initialState: Parent.State(
          children: StackState([
            Child.State(count: 1),
            Child.State(count: 2),
          ])
        )
      ) {
        Parent()
      } withDependencies: {
        $0.mainQueue = mainQueue.eraseToAnyScheduler()
      }

      await store.send(.child(.element(id: 0, action: .tap)))
      await store.send(.child(.element(id: 1, action: .tap)))
      await mainQueue.advance(by: .seconds(1))
      await store.receive(.child(.element(id: 0, action: .response(42)))) {
        $0.children[id: 0]?.count = 42
      }
      await mainQueue.advance(by: .seconds(1))
      await store.receive(.child(.element(id: 1, action: .response(42)))) {
        $0.children[id: 1]?.count = 42
      }
    }

    @MainActor
    func testChildEffectCancellation() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable { case tap }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            .run { _ in try await Task.never() }
          }
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children: StackState<Child.State>
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }
            .forEach(\.children, action: /Action.child) { Child() }
        }
      }

      let store = TestStore(
        initialState: Parent.State(
          children: StackState([
            Child.State()
          ])
        )
      ) {
        Parent()
      }

      await store.send(.child(.element(id: 0, action: .tap)))
      await store.send(.child(.popFrom(id: 0))) {
        $0.children[id: 0] = nil
      }
    }

    @MainActor
    func testPush() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {}
        var body: some Reducer<State, Action> {
          EmptyReducer()
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
          case push
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .push:
              state.children.append(Child.State())
              return .none
            }
          }
          .forEach(\.children, action: /Action.child) { Child() }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.child(.push(id: 0, state: Child.State()))) {
        $0.children[id: 0] = Child.State()
      }
      await store.send(.push) {
        $0.children[id: 1] = Child.State()
      }
      await store.send(.child(.push(id: 2, state: Child.State()))) {
        $0.children[id: 2] = Child.State()
      }
      await store.send(.push) {
        $0.children[id: 3] = Child.State()
      }
      await store.send(.child(.popFrom(id: 0))) {
        $0.children = StackState()
      }
      await store.send(.child(.push(id: 0, state: Child.State()))) {
        $0.children[id: 0] = Child.State()
      }
    }

    @MainActor
    func testPushReusedID() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {}
        var body: some Reducer<State, Action> {
          EmptyReducer()
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }
            .forEach(\.children, action: /Action.child) { Child() }
        }
      }
      let line = #line - 3

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A "forEach" at "ComposableArchitectureTests/StackReducerTests.swift:\(line)" received a \
          "push" action for an element it already contains. …

            ID:
              #0
            Path IDs:
              [#0]
          """
      }

      await store.send(.child(.push(id: 0, state: Child.State()))) {
        $0.children[id: 0] = Child.State()
      }
      await store.send(.child(.push(id: 0, state: Child.State())))
    }

    @MainActor
    func testPushIDGreaterThanNextGeneration() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {}
        var body: some Reducer<State, Action> {
          EmptyReducer()
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }
            .forEach(\.children, action: /Action.child) { Child() }
        }
      }
      let line = #line - 3

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A "forEach" at "ComposableArchitectureTests/StackReducerTests.swift:\(line)" received a \
          "push" action with an unexpected generational ID. …

            Received ID:
              #1
            Expected ID:
              #0
          """
      }

      await store.send(.child(.push(id: 1, state: Child.State()))) {
        $0.children[id: 1] = Child.State()
      }
    }

    @MainActor
    func testMismatchedIDFailure() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {}
        var body: some Reducer<State, Action> {
          EmptyReducer()
        }
      }
      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case child(StackActionOf<Child>)
        }
        var body: some ReducerOf<Self> {
          Reduce { _, _ in .none }.forEach(\.children, action: /Action.child) { Child() }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A state change does not match expectation: …

                StackReducerTests.Parent.State(
                  children: [
              −     #1: StackReducerTests.Child.State()
              +     #0: StackReducerTests.Child.State()
                  ]
                )

          (Expected: −, Actual: +)
          """
      }
      await store.send(.child(.push(id: 0, state: Child.State()))) {
        $0.children[id: 1] = Child.State()
      }
    }

    @MainActor
    func testSendCopiesStackElementIDGenerator() async {
      struct Feature: Reducer {
        struct State: Equatable {
          var path = StackState<Int>()
        }
        enum Action: Equatable {
          case buttonTapped
          case path(StackAction<Int, Never>)
          case response
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .buttonTapped:
              state.path.append(1)
              return .send(.response)
            case .path:
              return .none
            case .response:
              state.path.append(2)
              return .none
            }
          }
          .forEach(\.path, action: /Action.path) {}
        }
      }

      let store = TestStore(initialState: Feature.State()) {
        Feature()
      }

      await store.send(.buttonTapped) {
        $0.path[id: 0] = 1
        @Dependency(\.stackElementID) var stackElementID
        _ = stackElementID.next()
        _ = stackElementID.next()
        _ = stackElementID.next()
      }
      await store.receive(.response) {
        $0.path[id: 1] = 2
        @Dependency(\.stackElementID) var stackElementID
        _ = stackElementID.next()
        _ = stackElementID.next()
        _ = stackElementID.next()
      }
      await store.send(.buttonTapped) {
        $0.path[id: 2] = 1
      }
      await store.receive(.response) {
        $0.path[id: 3] = 2
      }
    }

    @MainActor
    func testOuterCancellation() async {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable { case onAppear }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            .run { _ in
              try await Task.never()
            }
          }
        }
      }

      struct Parent: Reducer {
        struct State: Equatable {
          var children = StackState<Child.State>()
        }
        enum Action: Equatable {
          case children(StackActionOf<Child>)
          case tapAfter
          case tapBefore
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .tapAfter:
              return .none
            case .tapBefore:
              state.children.removeAll()
              return .none
            }
          }

          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .tapAfter:
              return .none
            case .tapBefore:
              return .none
            }
          }
          .forEach(\.children, action: /Action.children) {
            Child()
          }

          Reduce { state, action in
            switch action {
            case .children:
              return .none
            case .tapAfter:
              state.children.removeAll()
              return .none
            case .tapBefore:
              return .none
            }
          }
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.children(.push(id: 0, state: Child.State()))) {
        $0.children[id: 0] = Child.State()
      }
      await store.send(.children(.element(id: 0, action: .onAppear)))
      await store.send(.tapBefore) {
        $0.children.removeAll()
      }

      await store.send(.children(.push(id: 1, state: Child.State()))) {
        $0.children[id: 1] = Child.State()
      }
      await store.send(.children(.element(id: 1, action: .onAppear)))
      await store.send(.tapAfter) {
        $0.children.removeAll()
      }
      // NB: Another action needs to come into the `ifLet` to cancel the child action
      await store.send(.tapAfter)
    }
  }
#endif
