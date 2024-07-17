import ComposableArchitecture
import XCTest

@available(*, deprecated, message: "TODO: Update to use case pathable syntax with Swift 5.9")
final class OnChangeReducerTests: BaseTCATestCase {
  @MainActor
  func testOnChange() async {
    struct Feature: Reducer {
      struct State: Equatable {
        var count = 0
        var description = ""
      }
      enum Action: Equatable {
        case incrementButtonTapped
        case decrementButtonTapped
      }
      var body: some ReducerOf<Self> {
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
        .onChange(of: \.count) { oldValue, newValue in
          Reduce { state, action in
            state.description = String(repeating: "!", count: newValue)
            return newValue > 1 ? .send(.decrementButtonTapped) : .none
          }
        }
      }
    }
    let store = TestStore(initialState: Feature.State()) { Feature() }
    await store.send(.incrementButtonTapped) {
      $0.count = 1
      $0.description = "!"
    }
    await store.send(.incrementButtonTapped) {
      $0.count = 2
      $0.description = "!!"
    }
    await store.receive(.decrementButtonTapped) {
      $0.count = 1
      $0.description = "!"
    }
  }

  @MainActor
  func testOnChangeChildStates() async {
    struct Feature: Reducer {
      struct ChildFeature: Reducer {
        struct State: Equatable, Identifiable {
          let id: Int
          var counter = 0
        }

        enum Action: Equatable {
          case incrementButtonTapped
        }

        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .incrementButtonTapped:
              state.counter += 1
              return .none
            }
          }
        }
      }

      struct State: Equatable {
        var childStates: IdentifiedArrayOf<ChildFeature.State>

        var onChangeUpdateCounter = 0
      }

      enum Action: Equatable {
        case addChildState(ChildFeature.State)

        case child(ChildFeature.State.ID, ChildFeature.Action)
      }

      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case let .addChildState(childState):
            state.childStates.append(childState)
            return .none
          case .child:
            return .none
          }
        }
        .forEach(
          \.childStates,
          action: /Action.child,
          element: ChildFeature.init
        )
        .onChange(
          of: \.childStates,
          removeDuplicates: { previousStates, newStates in
            // Only trigger onChange reducer when the childStates ids change
            previousStates.ids == newStates.ids
          }
        ) { _, _ in
          Reduce { state, action in
            state.onChangeUpdateCounter += 1
            return .none
          }
        }
      }
    }
    let store = TestStore(
      initialState: Feature.State(
        childStates: [
          .init(id: 0)
        ]
      )
    ) { Feature() }

    await store.send(.child(0, .incrementButtonTapped)) {
      // onChangeUpdateCounter should not increase as the child state changes
      // but from a parent reducer perspective nothing changes due to the passed
      // did change function.
      $0.childStates[id: 0]?.counter = 1
    }

    await store.send(.addChildState(.init(id: 1))) {
      $0.childStates.append(.init(id: 1))
      // onChangeUpdateCounter is increased here as a new screen is added
      // and the ids sets of `childStates` change.
      $0.onChangeUpdateCounter = 1
    }

    await store.send(.child(1, .incrementButtonTapped)) {
      $0.childStates[id: 1]?.counter = 1
    }
  }

  @MainActor
  func testOnChangeTuple() async {
    struct Feature: Reducer {
      struct State: Equatable {
        var countA = 0
        var countB = 0
        var sum = 0
      }
      enum Action: Equatable {
        case incrementButtonTapped
        case noop
        case updateSum(Int)
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .incrementButtonTapped:
            state.countA += 1
            state.countB += 1
            return .none
          case .noop:
            return .none
          case let .updateSum(sum):
            state.sum = sum
            return .none
          }
        }
        .onChange(
          of: { ($0.countA, $0.countB) },
          removeDuplicates: ==
        ) { _, _ in
          Reduce { state, action in
            return .send(.updateSum(state.countA + state.countB))
          }
        }
      }
    }

    let store = TestStore(
      initialState: Feature.State()
    ) { Feature() }

    await store.send(.incrementButtonTapped) {
      $0.countA = 1
      $0.countB = 1
    }

    await store.receive(.updateSum(2)) {
      $0.sum = 2
    }

    await store.send(.noop)
  }

  @MainActor
  func testSharedState() async {
    struct Count: Codable, Equatable {
      var value = 0
    }

    struct Feature: Reducer {
      struct State: Equatable {
        @Shared(.fileStorage(URL(fileURLWithPath: "/file.json"))) var count = Count()
        var description = ""
      }
      enum Action: Equatable {
        case incrementButtonTapped
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .incrementButtonTapped:
            state.count.value += 1
            return .none
          }
        }
        .onChange(of: \.count) { oldValue, newValue in
          Reduce { state, _ in
            state.description = "old: \(oldValue.value), new: \(newValue.value)"
            return .none
          }
        }
      }
    }
    let store = TestStore(initialState: Feature.State()) { Feature() }
    await store.send(.incrementButtonTapped) {
      $0.count.value = 1
      $0.description = "old: 0, new: 1"
    }
    await store.send(.incrementButtonTapped) {
      $0.count.value = 2
      $0.description = "old: 1, new: 2"
    }
  }
}
