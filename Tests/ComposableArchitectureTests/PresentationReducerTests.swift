import ComposableArchitecture
import XCTest

#if swift(>=5.7)
  @MainActor
  final class PresentationReducerTests: XCTestCase {
    func testPresentation_parentDismissal() async {
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
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .presents(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )

      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.incrementButtonTapped))) {
        try (/.some).modify(&$0.child) {
          $0.count = 1
        }
      }
      await store.send(.child(.dismiss)) {
        $0.child = nil
      }
    }

    func testPresentation_childDismissal() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case closeButtonTapped
          case decrementButtonTapped
          case incrementButtonTapped
        }
        @Dependency(\.dismiss) var dismiss
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .closeButtonTapped:
            return .fireAndForget {
              await self.dismiss()
            }
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
          var lastCount: Int?
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child(.dismiss):
              state.lastCount = state.child?.count
              return .none
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .presents(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )

      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.decrementButtonTapped))) {
        try (/.some).modify(&$0.child) {
          $0.count = -1
        }
      }
      await store.send(.child(.presented(.closeButtonTapped)))
      await store.receive(.child(.dismiss)) {
        $0.child = nil
        $0.lastCount = -1
      }
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func testPresentation_parentDismissal_effects() async {
      await _withMainSerialExecutor {
        struct Child: ReducerProtocol {
          struct State: Equatable {
            var count = 0
          }
          enum Action: Equatable {
            case startButtonTapped
            case tick
          }
          @Dependency(\.continuousClock) var clock
          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            switch action {
            case .startButtonTapped:
              return .run { send in
                for try await _ in clock.timer(interval: .seconds(1)) {
                  await send(.tick)
                }
              }
            case .tick:
              state.count += 1
              return .none
            }
          }
        }

        struct Parent: ReducerProtocol {
          struct State: Equatable {
            @PresentationState var child: Child.State?
          }
          enum Action: Equatable {
            case child(PresentationAction<Child.Action>)
            case presentChild
          }
          var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
              switch action {
              case .child:
                return .none
              case .presentChild:
                state.child = Child.State()
                return .none
              }
            }
            .presents(\.$child, action: /Action.child) {
              Child()
            }
          }
        }

        let clock = TestClock()
        let store = TestStore(
          initialState: Parent.State(),
          reducer: Parent()
        ) {
          $0.continuousClock = clock
        }

        await store.send(.presentChild) {
          $0.child = Child.State()
        }
        await store.send(.child(.presented(.startButtonTapped)))
        await clock.advance(by: .seconds(2))
        await store.receive(.child(.presented(.tick))) {
          try (/.some).modify(&$0.child) {
            $0.count = 1
          }
        }
        await store.receive(.child(.presented(.tick))) {
          try (/.some).modify(&$0.child) {
            $0.count = 2
          }
        }
        await store.send(.child(.dismiss)) {
          $0.child = nil
        }
      }
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func testPresentation_childDismissal_effects() async {
      await _withMainSerialExecutor {
        struct Child: ReducerProtocol {
          struct State: Equatable {
            var count = 0
          }
          enum Action: Equatable {
            case closeButtonTapped
            case startButtonTapped
            case tick
          }
          @Dependency(\.continuousClock) var clock
          @Dependency(\.dismiss) var dismiss
          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            switch action {
            case .closeButtonTapped:
              return .fireAndForget {
                await self.dismiss()
              }

            case .startButtonTapped:
              return .run { send in
                for try await _ in clock.timer(interval: .seconds(1)) {
                  await send(.tick)
                }
              }
            case .tick:
              state.count += 1
              return .none
            }
          }
        }

        struct Parent: ReducerProtocol {
          struct State: Equatable {
            @PresentationState var child: Child.State?
          }
          enum Action: Equatable {
            case child(PresentationAction<Child.Action>)
            case presentChild
          }
          var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
              switch action {
              case .child:
                return .none
              case .presentChild:
                state.child = Child.State()
                return .none
              }
            }
            .presents(\.$child, action: /Action.child) {
              Child()
            }
          }
        }

        let clock = TestClock()
        let store = TestStore(
          initialState: Parent.State(),
          reducer: Parent()
        ) {
          $0.continuousClock = clock
        }

        await store.send(.presentChild) {
          $0.child = Child.State()
        }
        await store.send(.child(.presented(.startButtonTapped)))
        await clock.advance(by: .seconds(2))
        await store.receive(.child(.presented(.tick))) {
          try (/.some).modify(&$0.child) {
            $0.count = 1
          }
        }
        await store.receive(.child(.presented(.tick))) {
          try (/.some).modify(&$0.child) {
            $0.count = 2
          }
        }
        await store.send(.child(.presented(.closeButtonTapped)))
        await store.receive(.child(.dismiss)) {
          $0.child = nil
        }
      }
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func testPresentation_identifiableDismissal_effects() async {
      await _withMainSerialExecutor {
        struct Child: ReducerProtocol {
          struct State: Equatable, Identifiable {
            let id: UUID
            var count = 0
          }
          enum Action: Equatable {
            case startButtonTapped
            case tick
          }
          @Dependency(\.continuousClock) var clock
          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            switch action {
            case .startButtonTapped:
              return .run { send in
                for try await _ in clock.timer(interval: .seconds(1)) {
                  await send(.tick)
                }
              }
            case .tick:
              state.count += 1
              return .none
            }
          }
        }

        struct Parent: ReducerProtocol {
          struct State: Equatable {
            @PresentationState var child: Child.State?
          }
          enum Action: Equatable {
            case child(PresentationAction<Child.Action>)
            case presentChild
          }
          @Dependency(\.uuid) var uuid
          var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
              switch action {
              case .child:
                return .none
              case .presentChild:
                state.child = Child.State(id: self.uuid())
                return .none
              }
            }
            .presents(\.$child, action: /Action.child) {
              Child()
            }
          }
        }

        let clock = TestClock()
        let store = TestStore(
          initialState: Parent.State(),
          reducer: Parent()
        ) {
          $0.continuousClock = clock
          $0.uuid = .incrementing
        }

        await store.send(.presentChild) {
          $0.child = Child.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        }
        await store.send(.child(.presented(.startButtonTapped)))
        await clock.advance(by: .seconds(2))
        await store.receive(.child(.presented(.tick))) {
          try (/.some).modify(&$0.child) {
            $0.count = 1
          }
        }
        await store.receive(.child(.presented(.tick))) {
          try (/.some).modify(&$0.child) {
            $0.count = 2
          }
        }
        await store.send(.presentChild) {
          $0.child = Child.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        }
        await clock.advance(by: .seconds(2))
        await store.send(.child(.dismiss)) {
          $0.child = nil
        }
      }
    }

    func testPresentation_requiresDismissal() async {
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
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .presents(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )

      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.skipInFlightEffects(strict: true)
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    func testInertPresentation() async {
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          @PresentationState var alert: AlertState<Action.Alert>?
        }
        enum Action: Equatable {
          case alert(PresentationAction<Alert>)
          case presentAlert

          enum Alert: Equatable {}
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .alert:
              return .none
            case .presentAlert:
              state.alert = AlertState {
                TextState("Uh oh!")
              }
              return .none
            }
          }
          .presents(\.$alert, action: /Action.alert) {}
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )

      await store.send(.presentAlert) {
        $0.alert = AlertState {
          TextState("Uh oh!")
        }
      }
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    func testInertPresentation_dismissal() async {
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          @PresentationState var alert: AlertState<Action.Alert>?
        }
        enum Action: Equatable {
          case alert(PresentationAction<Alert>)
          case presentAlert

          enum Alert: Equatable {}
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .alert:
              return .none
            case .presentAlert:
              state.alert = AlertState {
                TextState("Uh oh!")
              }
              return .none
            }
          }
          .presents(\.$alert, action: /Action.alert) {}
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )

      await store.send(.presentAlert) {
        $0.alert = AlertState {
          TextState("Uh oh!")
        }
      }
      await store.send(.alert(.dismiss)) {
        $0.alert = nil
      }
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
    func testInertPresentation_automaticDismissal() async {
      struct Parent: ReducerProtocol {
        struct State: Equatable {
          @PresentationState var alert: AlertState<Action.Alert>?
          var isDeleted = false
        }
        enum Action: Equatable {
          case alert(PresentationAction<Alert>)
          case presentAlert

          enum Alert: Equatable {
            case deleteButtonTapped
          }
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .alert(.presented(.deleteButtonTapped)):
              state.isDeleted = true
              return .none
            case .alert:
              return .none
            case .presentAlert:
              state.alert = AlertState {
                TextState("Uh oh!")
              } actions: {
                ButtonState(role: .destructive, action: .deleteButtonTapped) {
                  TextState("Delete")
                }
              }
              return .none
            }
          }
          .presents(\.$alert, action: /Action.alert) {}
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )

      await store.send(.presentAlert) {
        $0.alert = AlertState {
          TextState("Uh oh!")
        } actions: {
          ButtonState(role: .destructive, action: .deleteButtonTapped) {
            TextState("Delete")
          }
        }
      }
      await store.send(.alert(.presented(.deleteButtonTapped))) {
        $0.alert = nil
        $0.isDeleted = true
      }
    }

    func testPresentation_hydratedDestination_childDismissal() async {
      await _withMainSerialExecutor {
        struct Child: ReducerProtocol {
          struct State: Equatable {
            var count = 0
          }
          enum Action: Equatable {
            case closeButtonTapped
            case decrementButtonTapped
            case incrementButtonTapped
          }
          @Dependency(\.dismiss) var dismiss
          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            switch action {
            case .closeButtonTapped:
              return .fireAndForget {
                await self.dismiss()
              }
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
            @PresentationState var child: Child.State?
          }
          enum Action: Equatable {
            case child(PresentationAction<Child.Action>)
            case presentChild
          }
          var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
              switch action {
              case .child:
                return .none
              case .presentChild:
                state.child = Child.State()
                return .none
              }
            }
            .presents(\.$child, action: /Action.child) {
              Child()
            }
          }
        }
        
        let store = TestStore(
          initialState: Parent.State(child: Child.State()),
          reducer: Parent()
        )
        
        await store.send(.child(.presented(.closeButtonTapped)))
        await store.receive(.child(.dismiss)) {
          $0.child = nil
        }
      }
    }

    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func testEnumPresentation() async {
      await _withMainSerialExecutor {
        struct Child: ReducerProtocol {
          struct State: Equatable, Identifiable {
            let id: UUID
            var count = 0
          }
          enum Action: Equatable {
            case closeButtonTapped
            case startButtonTapped
            case tick
          }
          @Dependency(\.continuousClock) var clock
          @Dependency(\.dismiss) var dismiss
          func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
            switch action {
            case .closeButtonTapped:
              return .fireAndForget {
                await self.dismiss()
              }

            case .startButtonTapped:
              return .run { send in
                for try await _ in clock.timer(interval: .seconds(1)) {
                  await send(.tick)
                }
              }
            case .tick:
              state.count += 1
              return .none
            }
          }
        }

        struct Parent: ReducerProtocol {
          struct State: Equatable {
            @PresentationState var destination: Destinations.State?
            var isDeleted = false
          }
          enum Action: Equatable {
            case destination(PresentationAction<Destinations.Action>)
            case presentAlert
            case presentChild(id: UUID? = nil)
          }
          @Dependency(\.uuid) var uuid
          var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
              switch action {
              case .destination(.presented(.alert(.deleteButtonTapped))):
                state.isDeleted = true
                return .none
              case .destination:
                return .none
              case .presentAlert:
                state.destination = .alert(
                  AlertState {
                    TextState("Uh oh!")
                  } actions: {
                    ButtonState(role: .destructive, action: .deleteButtonTapped) {
                      TextState("Delete")
                    }
                  }
                )
                return .none
              case let .presentChild(id):
                state.destination = .child(Child.State(id: id ?? self.uuid()))
                return .none
              }
            }
            .presents(\.$destination, action: /Action.destination) {
              Destinations()
            }
          }
          struct Destinations: ReducerProtocol {
            enum State: Equatable {
              case alert(AlertState<Action.Alert>)
              case child(Child.State)
            }
            enum Action: Equatable {
              case alert(Alert)
              case child(Child.Action)

              enum Alert: Equatable {
                case deleteButtonTapped
              }
            }
            var body: some ReducerProtocol<State, Action> {
              Scope(state: /State.alert, action: /Action.alert) {}
              Scope(state: /State.child, action: /Action.child) {
                Child()
              }
            }
          }
        }

        let clock = TestClock()
        let store = TestStore(
          initialState: Parent.State(),
          reducer: Parent()
        ) {
          $0.continuousClock = clock
          $0.uuid = .incrementing
        }

        await store.send(.presentChild()) {
          $0.destination = .child(
            Child.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
          )
        }
        await store.send(.destination(.presented(.child(.startButtonTapped))))
        await clock.advance(by: .seconds(2))
        await store.receive(.destination(.presented(.child(.tick)))) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 1
          }
        }
        await store.receive(.destination(.presented(.child(.tick)))) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 2
          }
        }
        await store.send(.destination(.presented(.child(.closeButtonTapped))))
        await store.receive(.destination(.dismiss)) {
          $0.destination = nil
        }
        await store.send(.presentChild()) {
          $0.destination = .child(
            Child.State(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
          )
        }
        await clock.advance(by: .seconds(2))
        await store.send(.destination(.presented(.child(.startButtonTapped))))
        await clock.advance(by: .seconds(2))
        await store.receive(.destination(.presented(.child(.tick)))) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 1
          }
        }
        await store.receive(.destination(.presented(.child(.tick)))) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 2
          }
        }
        await store.send(
          .presentChild(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        ) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 0
          }
        }
        await clock.advance(by: .seconds(2))
        await store.receive(.destination(.presented(.child(.tick)))) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 1
          }
        }
        await store.receive(.destination(.presented(.child(.tick)))) {
          try (/Parent.Destinations.State.child).modify(&$0.destination) {
            $0.count = 2
          }
        }
        await store.send(.presentAlert) {
          $0.destination = .alert(
            AlertState {
              TextState("Uh oh!")
            } actions: {
              ButtonState(role: .destructive, action: .deleteButtonTapped) {
                TextState("Delete")
              }
            }
          )
        }
        await store.send(.destination(.presented(.alert(.deleteButtonTapped)))) {
          $0.destination = nil
          $0.isDeleted = true
        }
      }
    }

    func testNavigation_cancelID_childCancellation() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case startButtonTapped
          case stopButtonTapped
        }
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .startButtonTapped:
            return .fireAndForget {
              try await Task.never()
            }
            .cancellable(id: 42)

          case .stopButtonTapped:
            return .cancel(id: 42)
          }
        }
      }

      struct Parent: ReducerProtocol {
        struct State: Equatable {
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .presents(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )
      let presentationTask = await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.startButtonTapped)))
      await store.send(.child(.presented(.stopButtonTapped)))
      await presentationTask.cancel()
    }


    func testNavigation_cancelID_parentCancellation() async {
      struct Child: ReducerProtocol {
        struct State: Equatable {}
        enum Action: Equatable {
          case startButtonTapped
        }
        func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
          switch action {
          case .startButtonTapped:
            return .fireAndForget {
              try await Task.never()
            }
            .cancellable(id: 42)
          }
        }
      }

      struct Parent: ReducerProtocol {
        struct State: Equatable {
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case localCancel
          case presentChild
        }
        var body: some ReducerProtocol<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .localCancel:
              return .cancel(id: 42)
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .presents(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      )
      let presentationTask = await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.startButtonTapped)))
      await store.send(.localCancel)
      await presentationTask.cancel()
    }

    // TODO: Capture all the below:
    // child effect (id: 42), parent sends cancel(id: 42) -> CANCEL
    // childA effect (id: 42), childB effect(id: 42) -> parent sends cancel(id: 42) -> CANCEL BOTH
    // childA effect (id: 42), childB effect(id: 42) -> childA sends cancel(id: 42) -> CANCEL A
  }
#endif
