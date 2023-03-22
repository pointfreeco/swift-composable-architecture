import ComposableArchitecture
import XCTest

#if swift(>=5.7)
  @MainActor
  final class StackReducerTests: XCTestCase {
    func testPresent() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case decrementButtonTapped
          case incrementButtonTapped
        }
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var children: StackState<Child.State> = []
        }
        enum Action: Equatable {
          case children(StackAction<Child.Action>)
          case pushChild
        }
        var body: some ReducerProtocol<State, Action> {
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

      let store = TestStore(initialState: Parent.State(), reducer: Parent())

      await store.send(.pushChild) {
        $0.children = [
          Child.State()
        ]
      }
    }

    func testDismissFromParent() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case onAppear
        }
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .onAppear:
            return .fireAndForget {
              try await Task.never()
            }
          }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var children: StackState<Child.State> = []
        }
        enum Action: Equatable {
          case children(StackAction<Child.Action>)
          case popChild
          case pushChild
        }
        var body: some ReducerProtocol<State, Action> {
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

      let store = TestStore(initialState: Parent.State(), reducer: Parent())

      await store.send(.pushChild) {
        $0.children = [
          Child.State()
        ]
      }
      await store.send(.children(.element(id: 0, action: .onAppear)))
      await store.send(.popChild) {
        $0.children = []
      }
    }

    func testDismissFromChild() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case closeButtonTapped
          case onAppear
        }
        @Dependency(\.dismiss) var dismiss
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .closeButtonTapped:
            return .fireAndForget {
              await self.dismiss()
            }
          case .onAppear:
            return .fireAndForget {
              try await Task.never()
            }
          }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var children: StackState<Child.State> = []
        }
        enum Action: Equatable {
          case children(StackAction<Child.Action>)
          case pushChild
        }
        var body: some ReducerProtocol<State, Action> {
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

      let store = TestStore(initialState: Parent.State(), reducer: Parent())

      await store.send(.pushChild) {
        $0.children = [
          Child.State()
        ]
      }
      await store.send(.children(.element(id: 0, action: .onAppear)))
      await store.send(.children(.element(id: 0, action: .closeButtonTapped)))
      await store.receive(.children(.popFrom(id: 0))) {
        $0.children = []
      }
    }

    func testDismissFromDeepLinkedChild() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case closeButtonTapped
        }
        @Dependency(\.dismiss) var dismiss
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .closeButtonTapped:
            return .fireAndForget {
              await self.dismiss()
            }
          }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var children: StackState<Child.State> = []
        }
        enum Action: Equatable {
          case children(StackAction<Child.Action>)
          case pushChild
        }
        var body: some ReducerProtocol<State, Action> {
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

      let store = TestStore(
        initialState: Parent.State(children: [Child.State()]), reducer: Parent())

      await store.send(.children(.element(id: 0, action: .closeButtonTapped)))
      await store.receive(.children(.popFrom(id: 0))) {
        $0.children = []
      }
    }

    func testEnumChild() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case closeButtonTapped
          case incrementButtonTapped
          case onAppear
        }
        @Dependency(\.dismiss) var dismiss
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .closeButtonTapped:
            return .fireAndForget {
              await self.dismiss()
            }
          case .incrementButtonTapped:
            state.count += 1
            return .none
          case .onAppear:
            return .fireAndForget {
              try await Task.never()
            }
          }
        }
      }
      struct Navigation: ReducerProtocol {
        enum State: Equatable {
          case child1(Child.State)
          case child2(Child.State)
        }
        enum Action: Equatable {
          case child1(Child.Action)
          case child2(Child.Action)
        }
        var body: some ReducerProtocol<State, Action> {
          Scope(state: /State.child1, action: /Action.child1) {
            Child()
          }
          Scope(state: /State.child2, action: /Action.child2) {
            Child()
          }
        }
      }
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          var navigation: StackState<Navigation.State> = []
        }
        enum Action: Equatable {
          case navigation(StackAction<Navigation.Action>)
          case pushChild1
          case pushChild2
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .navigation:
              return .none
            case .pushChild1:
              state.navigation.append(.child1(Child.State()))
              return .none
            case .pushChild2:
              state.navigation.append(.child2(Child.State()))
              return .none
            }
          }
          .forEach(\.navigation, action: /Action.navigation) {
            Navigation()
          }
        }
      }

      let store = TestStore(initialState: Parent.State(), reducer: Parent()._printChanges())
      await store.send(.pushChild1) {
        /*
       $0.navigation = [
         0: .child1(Child.State())
       ]
       $0.navigation[id: 0] = .child1(Child.State())
       $0.append(id: 0, .child1(Child.State()) // Too many overloads?
       $0.append(.child1(Child.State())
       */
        $0.navigation = [
          .child1(Child.State())
        ]
      }
      await store.send(.navigation(.element(id: 0, action: .child1(.onAppear))))
      await store.send(.pushChild2) {
        $0.navigation = [
          .child1(Child.State()),
          .child2(Child.State()),
        ]
      }
      await store.send(.navigation(.element(id: 1, action: .child2(.onAppear))))
      await store.send(.navigation(.popFrom(id: 0))) {
        $0.navigation = []
      }
      // TODO: Fix crash
//      await store.send(.navigation(.element(id: 2, action: .child2(.onAppear))))
    }
  }
#endif
