import ComposableArchitecture
@_spi(Concurrency) import Dependencies
import XCTest

@MainActor
final class IfLetReducerTests: BaseTCATestCase {
  #if DEBUG
    func testNilChild() async {
      let store = TestStore(initialState: Int?.none) {
        EmptyReducer<Int?, Void>()
          .ifLet(\.self, action: /.self) {}
      }

      XCTExpectFailure {
        $0.compactDescription == """
          An "ifLet" at "\(#fileID):\(#line - 5)" received a child action when child state was \
          "nil". …

            Action:
              ()

          This is generally considered an application logic error, and can happen for a few \
          reasons:

          • A parent reducer set child state to "nil" before this reducer ran. This reducer must \
          run before any other reducer sets child state to "nil". This ensures that child \
          reducers can handle their actions while their state is still available.

          • An in-flight effect emitted this action when child state was "nil". While it may be \
          perfectly reasonable to ignore this action, consider canceling the associated effect \
          before child state becomes "nil", especially if it is a long-living effect.

          • This action was sent to the store while state was "nil". Make sure that actions for \
          this reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
          applications, use "IfLetStore".
          """
      }

      await store.send(())
    }
  #endif

  func testEffectCancellation() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: ReducerProtocol {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case timerButtonTapped
          case timerTick
        }
        @Dependency(\.continuousClock) var clock
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .timerButtonTapped:
            return .run { send in
              for await _ in self.clock.timer(interval: .seconds(1)) {
                await send(.timerTick)
              }
            }
          case .timerTick:
            state.count += 1
            return .none
          }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var child: Child.State?
        }
        enum Action: Equatable {
          case child(Child.Action)
          case childButtonTapped
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .childButtonTapped:
              state.child = state.child == nil ? Child.State() : nil
              return .none
            }
          }
          .ifLet(\.child, action: /Action.child) {
            Child()
          }
        }
      }
      await withMainSerialExecutor {
        let clock = TestClock()
        let store = TestStore(initialState: Parent.State()) {
          Parent()
        } withDependencies: {
          $0.continuousClock = clock
        }
        await store.send(.childButtonTapped) {
          $0.child = Child.State()
        }
        await store.send(.child(.timerButtonTapped))
        await clock.advance(by: .seconds(2))
        await store.receive(.child(.timerTick)) {
          try (/.some).modify(&$0.child) {
            $0.count = 1
          }
        }
        await store.receive(.child(.timerTick)) {
          try (/.some).modify(&$0.child) {
            $0.count = 2
          }
        }
        await store.send(.childButtonTapped) {
          $0.child = nil
        }
      }
    }
  }

  func testGrandchildEffectCancellation() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct GrandChild: ReducerProtocol {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case timerButtonTapped
          case timerTick
        }
        @Dependency(\.continuousClock) var clock
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .timerButtonTapped:
            return .run { send in
              for await _ in self.clock.timer(interval: .seconds(1)) {
                await send(.timerTick)
              }
            }
          case .timerTick:
            state.count += 1
            return .none
          }
        }
      }
      struct Child: ReducerProtocol {
        struct State: Equatable {
          var grandChild: GrandChild.State?
        }
        enum Action: Equatable {
          case grandChild(GrandChild.Action)
        }
        var body: some ReducerProtocol<State, Action> {
          EmptyReducer()
            .ifLet(\.grandChild, action: /Action.grandChild) {
              GrandChild()
            }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var child: Child.State?
        }
        enum Action: Equatable {
          case child(Child.Action)
          case exitButtonTapped
          case startButtonTapped
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .exitButtonTapped:
              state.child = nil
              return .none
            case .startButtonTapped:
              state.child = Child.State(grandChild: GrandChild.State())
              return .none
            }
          }
          .ifLet(\.child, action: /Action.child) {
            Child()
          }
        }
      }
      await withMainSerialExecutor {
        let clock = TestClock()
        let store = TestStore(initialState: Parent.State()) {
          Parent()
        } withDependencies: {
          $0.continuousClock = clock
        }
        await store.send(.startButtonTapped) {
          $0.child = Child.State(grandChild: GrandChild.State())
        }
        await store.send(.child(.grandChild(.timerButtonTapped)))
        await clock.advance(by: .seconds(1))
        await store.receive(.child(.grandChild(.timerTick))) {
          try (/.some).modify(&$0.child) {
            try (/.some).modify(&$0.grandChild) {
              $0.count = 1
            }
          }
        }
        await store.send(.exitButtonTapped) {
          $0.child = nil
        }
      }
    }
  }

  func testEphemeralState() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var alert: AlertState<AlertAction>?
        }
        enum Action: Equatable {
          case alert(AlertAction)
          case tap
        }
        enum AlertAction { case ok }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .alert:
              return .none
            case .tap:
              state.alert = AlertState { TextState("Hi!") }
              return .none
            }
          }
          .ifLet(\.alert, action: /Action.alert) {
          }
        }
      }
      await withMainSerialExecutor {
        let store = TestStore(initialState: Parent.State()) {
          Parent()
        }
        await store.send(.tap) {
          $0.alert = AlertState { TextState("Hi!") }
        }
        await store.send(.alert(.ok)) {
          $0.alert = nil
        }
      }
    }
  }

  func testIdentifiableChild() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var child: Child.State?
      }
      enum Action: Equatable {
        case child(Child.Action)
        case newChild
      }
      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .newChild:
            guard let childState = state.child
            else { return .none }
            state.child = Child.State(id: childState.id + 1)
            return .none
          }
        }
        .ifLet(\.child, action: /Action.child) { Child() }
      }
    }
    struct Child: ReducerProtocol {
      struct State: Equatable, Identifiable {
        let id: Int
        var value = 0
      }
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.mainQueue) var mainQueue
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {

        case .tap:
          return .run { [id = state.id] send in
            try await mainQueue.sleep(for: .seconds(0))
            await send(.response(id))
          }
        case let .response(value):
          state.value = value
          return .none
        }
      }
    }

    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: Feature.State(child: Child.State(id: 1))) {
      Feature()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.child(.tap))
    await store.send(.newChild) {
      $0.child = Child.State(id: 2)
    }
    await store.send(.child(.tap))
    await mainQueue.advance()
    await store.receive(.child(.response(2))) {
      $0.child = Child.State(id: 2, value: 2)
    }
  }

  func testEphemeralDismissal() async {
    struct Feature: ReducerProtocol {
      struct State: Equatable {
        var alert: AlertState<AlertAction>?
      }
      enum Action: Equatable {
        case alert(AlertAction)
        case tap
      }
      enum AlertAction: Equatable {
        case again
        case ok
      }
      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .alert(.ok):
            return .none
          case .alert(.again), .tap:
            state.alert = AlertState(title: TextState("Hello"))
            return .none
          }
        }
        .ifLet(\.alert, action: /Action.alert)
      }
    }

    let store = TestStore(initialState: Feature.State()) { Feature() }

    await store.send(.tap) {
      $0.alert = AlertState(title: TextState("Hello"))
    }
    await store.send(.alert(.again))
    await store.send(.alert(.ok)) {
      $0.alert = nil
    }
  }
}
