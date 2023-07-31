import ComposableArchitecture
import XCTest

@MainActor
final class ForEachReducerTests: BaseTCATestCase {
  func testElementAction() async {
    let store = TestStore(
      initialState: Elements.State(
        rows: [
          .init(id: 1, value: "Blob"),
          .init(id: 2, value: "Blob Jr."),
          .init(id: 3, value: "Blob Sr."),
        ]
      )
    ) {
      Elements()
    }

    await store.send(.row(id: 1, action: "Blob Esq.")) {
      $0.rows[id: 1]?.value = "Blob Esq."
    }
    await store.send(.row(id: 2, action: "")) {
      $0.rows[id: 2]?.value = ""
    }
    await store.receive(.row(id: 2, action: "Empty")) {
      $0.rows[id: 2]?.value = "Empty"
    }
  }

  func testNonElementAction() async {
    let store = TestStore(initialState: Elements.State()) {
      Elements()
    }

    await store.send(.buttonTapped)
  }

  #if DEBUG
    func testMissingElement() async {
      let store = TestStore(initialState: Elements.State()) {
        EmptyReducer<Elements.State, Elements.Action>()
          .forEach(\.rows, action: /Elements.Action.row) {}
      }

      XCTExpectFailure {
        $0.compactDescription == """
          A "forEach" at "\(#fileID):\(#line - 5)" received an action for a missing element. …

            Action:
              Elements.Action.row(id:, action:)

          This is generally considered an application logic error, and can happen for a few reasons:

          • A parent reducer removed an element with this ID before this reducer ran. This reducer \
          must run before any other reducer removes an element, which ensures that element reducers \
          can handle their actions while their state is still available.

          • An in-flight effect emitted this action when state contained no element at this ID. \
          While it may be perfectly reasonable to ignore this action, consider canceling the \
          associated effect before an element is removed, especially if it is a long-living effect.

          • This action was sent to the store while its state contained no element at this ID. To \
          fix this make sure that actions for this reducer can only be sent from a view store when \
          its state contains an element at this id. In SwiftUI applications, use "ForEachStore".
          """
      }

      await store.send(.row(id: 1, action: "Blob Esq."))
    }
  #endif

  func testAutomaticEffectCancellation() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Timer: Reducer {
        struct State: Equatable, Identifiable {
          let id: UUID
          var elapsed = 0
        }
        enum Action: Equatable {
          case startButtonTapped
          case tick
        }
        @Dependency(\.continuousClock) var clock
        func reduce(into state: inout State, action: Action) -> Effect<Action> {
          switch action {
          case .startButtonTapped:
            return .run { send in
              for await _ in self.clock.timer(interval: .seconds(1)) {
                await send(.tick)
              }
            }
          case .tick:
            state.elapsed += 1
            return .none
          }
        }
      }
      struct Timers: Reducer {
        struct State: Equatable {
          var timers: IdentifiedArrayOf<Timer.State> = []
        }
        enum Action: Equatable {
          case addTimerButtonTapped
          case removeLastTimerButtonTapped
          case timers(id: Timer.State.ID, action: Timer.Action)
        }
        @Dependency(\.uuid) var uuid
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .addTimerButtonTapped:
              state.timers.append(Timer.State(id: self.uuid()))
              return .none
            case .removeLastTimerButtonTapped:
              state.timers.removeLast()
              return .none
            case .timers:
              return .none
            }
          }
          .forEach(\.timers, action: /Action.timers) {
            Timer()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Timers.State()) {
        Timers()
      } withDependencies: {
        $0.uuid = .incrementing
        $0.continuousClock = clock
      }
      await store.send(.addTimerButtonTapped) {
        $0.timers = [
          Timer.State(id: UUID(0))
        ]
      }
      await store.send(
        .timers(
          id: UUID(0),
          action: .startButtonTapped
        )
      )
      await clock.advance(by: .seconds(2))
      await store.receive(
        .timers(
          id: UUID(0),
          action: .tick
        )
      ) {
        $0.timers[0].elapsed = 1
      }
      await store.receive(
        .timers(
          id: UUID(0),
          action: .tick
        )
      ) {
        $0.timers[0].elapsed = 2
      }
      await store.send(.addTimerButtonTapped) {
        $0.timers = [
          Timer.State(
            id: UUID(0), elapsed: 2),
          Timer.State(id: UUID(1)),
        ]
      }
      await clock.advance(by: .seconds(1))
      await store.receive(
        .timers(
          id: UUID(0),
          action: .tick
        )
      ) {
        $0.timers[0].elapsed = 3
      }
      await store.send(
        .timers(
          id: UUID(1),
          action: .startButtonTapped
        )
      )
      await clock.advance(by: .seconds(1))
      await store.receive(
        .timers(
          id: UUID(0),
          action: .tick
        )
      ) {
        $0.timers[0].elapsed = 4
      }
      await store.receive(
        .timers(
          id: UUID(1),
          action: .tick
        )
      ) {
        $0.timers[1].elapsed = 1
      }
      await store.send(.removeLastTimerButtonTapped) {
        $0.timers = [
          Timer.State(id: UUID(0), elapsed: 4)
        ]
      }
      await clock.advance(by: .seconds(1))
      await store.receive(
        .timers(
          id: UUID(0),
          action: .tick
        )
      ) {
        $0.timers[0].elapsed = 5
      }
      await store.send(.removeLastTimerButtonTapped) {
        $0.timers = []
      }
    }
  }
}

struct Elements: Reducer {
  struct State: Equatable {
    struct Row: Equatable, Identifiable {
      var id: Int
      var value: String
    }
    var rows: IdentifiedArrayOf<Row> = []
  }
  enum Action: Equatable {
    case buttonTapped
    case row(id: Int, action: String)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      .none
    }
    .forEach(\.rows, action: /Action.row) {
      Reduce { state, action in
        state.value = action
        return action.isEmpty
          ? .run { await $0("Empty") }
          : .none
      }
    }
  }
}
