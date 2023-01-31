//import Combine
//import ComposableArchitecture
//import XCTest
//
//@MainActor
//@available(macOS 13, *)
//final class PresentationTests: XCTestCase {
//  func testCancellation() async {
//    struct Child: ReducerProtocol {
//      struct State: Equatable {
//        var count = 0
//      }
//
//      enum Action: Equatable {
//        case task
//        case tick
//      }
//
//      @Dependency(\.continuousClock) var clock
//
//      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
//        switch action {
//        case .task:
//          return .run { send in
//            for try await _ in self.clock.timer(interval: .seconds(1)) {
//              await send(.tick)
//            }
//          }
//        case .tick:
//          state.count += 1
//          return .none
//        }
//      }
//    }
//
//    struct Parent: ReducerProtocol {
//      struct State: Equatable {
//        @PresentationState var child: Child.State?
//      }
//
//      enum Action: Equatable {
//        case child(PresentationAction<Child.Action>)
//        case dismissChild
//        case presentChild
//      }
//
//      var body: some ReducerProtocol<State, Action> {
//        Reduce { state, action in
//          switch action {
//          case .child:
//            return .none
//          case .dismissChild:
//            state.child = nil
//            return .none
//          case .presentChild:
//            state.child = Child.State()
//            return .none
//          }
//        }
//        .presentationDestination(state: \.$child, action: /Action.child) {
//          Child()
//        }
//      }
//    }
//
//    let clock = TestClock()
//    let store = TestStore(
//      initialState: Parent.State(),
//      reducer: Parent()
//    ) {
//      $0.continuousClock = clock
//    }
//
//    await store.send(.presentChild) {
//      $0.child = Child.State()
//    }
//    await store.send(.child(.presented(.task)))
//    await store.send(.child(.dismiss)) {
//      $0.child = nil
//    }
//    //    await store.send(.dismissChild) {
//    //      $0.child = nil
//    //    }
//  }
//
//  func testCancellation2() async {
//    struct Child: ReducerProtocol {
//      struct State: Equatable, Identifiable {
//        let id: Int
//        var count = 0
//      }
//
//      enum Action: Equatable {
//        case task
//        case tick
//      }
//
//      @Dependency(\.continuousClock) var clock
//
//      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
//        switch action {
//        case .task:
//          return .run { send in
//            for try await _ in self.clock.timer(interval: .seconds(1)) {
//              await send(.tick)
//            }
//          }
//        case .tick:
//          state.count += 1
//          return .none
//        }
//      }
//    }
//
//    struct Parent: ReducerProtocol {
//      struct State: Equatable {
//        @PresentationState var child1: Child.State?
//        @PresentationState var child2: Child.State?
//      }
//
//      enum Action: Equatable {
//        case child1(PresentationAction<Child.Action>)
//        case child2(PresentationAction<Child.Action>)
//        case dismissChild1
//        case dismissChild2
//        case presentChild1
//        case presentChild2
//      }
//
//      var body: some ReducerProtocol<State, Action> {
//        Reduce { state, action in
//          switch action {
//          case .child1:
//            return .none
//          case .child2:
//            return .none
//          case .dismissChild1:
//            state.child1 = nil
//            return .none
//          case .dismissChild2:
//            state.child2 = nil
//            return .none
//          case .presentChild1:
//            state.child1 = Child.State(id: 1)
//            return .none
//          case .presentChild2:
//            state.child2 = Child.State(id: 2)
//            return .none
//          }
//        }
//        .presentationDestination(state: \.$child1, action: /Action.child1) {
//          Child()
//        }
//        .presentationDestination(state: \.$child2, action: /Action.child2) {
//          Child()
//        }
//      }
//    }
//
//    let clock = TestClock()
//    let store = TestStore(
//      initialState: Parent.State(),
//      reducer: Parent()
//    ) {
//      $0.continuousClock = clock
//    }
//
//    await store.send(.presentChild1) {
//      $0.child1 = Child.State(id: 1)
//    }
//    await store.send(.presentChild2) {
//      $0.child2 = Child.State(id: 2)
//    }
//    await store.send(.child1(.presented(.task)))
//    await store.send(.child1(.dismiss)) {
//      $0.child1 = nil
//    }
//  }
//
//  func testCancellation3() async {
//    struct Child: ReducerProtocol {
//      struct State: Equatable, Identifiable {
//        let id: Int
//        var count = 0
//      }
//
//      enum Action: Equatable {
//        case task
//        case tick
//      }
//
//      @Dependency(\.continuousClock) var clock
//
//      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
//        switch action {
//        case .task:
//          return .run { send in
//            for try await _ in self.clock.timer(interval: .seconds(1)) {
//              await send(.tick)
//            }
//          }
//        case .tick:
//          state.count += 1
//          return .none
//        }
//      }
//    }
//
//    struct Parent: ReducerProtocol {
//      struct Destinations: ReducerProtocol {
//        enum State: Equatable {
//          case child1(Child.State)
//          case child2(Child.State)
//        }
//
//        enum Action: Equatable {
//          case child1(Child.Action)
//          case child2(Child.Action)
//        }
//
//        var body: some ReducerProtocol<State, Action> {
//          Scope(state: /State.child1, action: /Action.child1) {
//            Child()
//          }
//          Scope(state: /State.child2, action: /Action.child2) {
//            Child()
//          }
//        }
//      }
//
//      struct State: Equatable {
//        @PresentationState var destination: Destinations.State?
//      }
//
//      enum Action: Equatable {
//        case destination(PresentationAction<Destinations.Action>)
//        case dismiss
//        case present
//      }
//
//      var body: some ReducerProtocol<State, Action> {
//        Reduce { state, action in
//          switch action {
//          case .destination:
//            return .none
//          case .dismiss:
//            state.destination = nil
//            return .none
//          case .present:
//            state.destination = .child1(Child.State(id: 1))
//            return .none
//          }
//        }
//        .presentationDestination(state: \.$destination, action: /Action.destination) {
//          Destinations()
//        }
//      }
//    }
//
//    let clock = TestClock()
//    let store = TestStore(
//      initialState: Parent.State(),
//      reducer: Parent()
//    ) {
//      $0.continuousClock = clock
//    }
//
//    await store.send(.present) {
//      $0.destination = .child1(Child.State(id: 1))
//    }
//    await store.send(.destination(.presented(.child1(.task))))
//    await store.send(.dismiss) {
//      $0.destination = nil
//    }
//  }}
