import ComposableArchitecture
import XCTest

@available(*, deprecated, message: "TODO: Update to use case pathable syntax with Swift 5.9")
final class PresentationReducerTests: BaseTCATestCase {
  @MainActor
  func testPresentationStateSubscriptCase() {
    enum Child: Equatable {
      case int(Int)
      case text(String)
    }

    struct Parent: Equatable {
      @PresentationState var child: Child?
    }

    var parent = Parent(child: .int(42))

    parent.$child[case: /Child.int]? += 1
    XCTAssertEqual(parent.child, .int(43))

    parent.$child[case: /Child.int] = nil
    XCTAssertNil(parent.child)
  }

  @MainActor
  func testPresentationStateSubscriptCase_Unexpected() {
    enum Child: Equatable {
      case int(Int)
      case text(String)
    }

    struct Parent: Equatable {
      @PresentationState var child: Child?
    }

    var parent = Parent(child: .int(42))

    XCTExpectFailure {
      parent.$child[case: /Child.text]?.append("!")
    } issueMatcher: {
      $0.compactDescription == """
        Can't modify unrelated case "int"
        """
    }

    XCTExpectFailure {
      parent.$child[case: /Child.text] = nil
    } issueMatcher: {
      $0.compactDescription == """
        Can't modify unrelated case "int"
        """
    }

    XCTAssertEqual(parent.child, .int(42))
  }

  @MainActor
  func testPresentation_parentDismissal() async {
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
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.incrementButtonTapped))) {
      XCTModify(&$0.child) {
        $0.count = 1
      }
    }
    await store.send(.child(.dismiss)) {
      $0.child = nil
    }
  }

  @MainActor
  func testPresentation_parentDismissal_NilOut() async {
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
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case dismissChild
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .dismissChild:
            state.child = nil
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.incrementButtonTapped))) {
      XCTModify(&$0.child) {
        $0.count = 1
      }
    }
    await store.send(.dismissChild) {
      $0.child = nil
    }
  }

  @MainActor
  func testPresentation_childDismissal() async {
    struct Child: Reducer {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case closeButtonTapped
        case decrementButtonTapped
        case incrementButtonTapped
      }
      @Dependency(\.dismiss) var dismiss
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .closeButtonTapped:
            return .run { _ in
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
    }

    struct Parent: Reducer {
      struct State: Equatable {
        var lastCount: Int?
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
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
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.decrementButtonTapped))) {
      XCTModify(&$0.child) {
        $0.count = -1
      }
    }
    await store.send(.child(.presented(.closeButtonTapped)))
    await store.receive(.child(.dismiss)) {
      $0.child = nil
      $0.lastCount = -1
    }
  }

  @MainActor
  func testPresentation_parentDismissal_effects() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case startButtonTapped
          case tick
        }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
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
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .ifLet(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }

      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(2))
      await store.receive(.child(.presented(.tick))) {
        XCTModify(&$0.child) {
          $0.count = 1
        }
      }
      await store.receive(.child(.presented(.tick))) {
        XCTModify(&$0.child) {
          $0.count = 2
        }
      }
      await store.send(.child(.dismiss)) {
        $0.child = nil
      }
    }
  }

  @MainActor
  func testPresentation_childDismissal_effects() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
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
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .closeButtonTapped:
              return .run { _ in
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
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .ifLet(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }

      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(2))
      await store.receive(.child(.presented(.tick))) {
        XCTModify(&$0.child) {
          $0.count = 1
        }
      }
      await store.receive(.child(.presented(.tick))) {
        XCTModify(&$0.child) {
          $0.count = 2
        }
      }
      await store.send(.child(.presented(.closeButtonTapped)))
      await store.receive(.child(.dismiss)) {
        $0.child = nil
      }
    }
  }

  @MainActor
  func testPresentation_identifiableDismissal_effects() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable, Identifiable {
          let id: UUID
          var count = 0
        }
        enum Action: Equatable {
          case startButtonTapped
          case tick
        }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
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
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
        }
        @Dependency(\.uuid) var uuid
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State(id: self.uuid())
              return .none
            }
          }
          .ifLet(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
        $0.uuid = .incrementing
      }

      await store.send(.presentChild) {
        $0.child = Child.State(id: UUID(0))
      }
      await store.send(.child(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(2))
      await store.receive(.child(.presented(.tick))) {
        XCTModify(&$0.child) {
          $0.count = 1
        }
      }
      await store.receive(.child(.presented(.tick))) {
        XCTModify(&$0.child) {
          $0.count = 2
        }
      }
      await store.send(.presentChild) {
        $0.child = Child.State(id: UUID(1))
      }
      await clock.advance(by: .seconds(2))
      await store.send(.child(.dismiss)) {
        $0.child = nil
      }
    }
  }

  @MainActor
  func testPresentation_LeavePresented() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
  }

  @MainActor
  func testPresentation_LeavePresented_FinishStore() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.finish()
  }

  @MainActor
  func testInertPresentation() async {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var alert: AlertState<Action.Alert>?
        }
        enum Action: Equatable {
          case alert(PresentationAction<Alert>)
          case presentAlert

          enum Alert: Equatable {}
        }
        var body: some ReducerOf<Self> {
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
          .ifLet(\.$alert, action: /Action.alert) {}
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.presentAlert) {
        $0.alert = AlertState {
          TextState("Uh oh!")
        }
      }
    }
  }

  @MainActor
  func testInertPresentation_dismissal() async {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var alert: AlertState<Action.Alert>?
        }
        enum Action: Equatable {
          case alert(PresentationAction<Alert>)
          case presentAlert

          enum Alert: Equatable {}
        }
        var body: some ReducerOf<Self> {
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
          .ifLet(\.$alert, action: /Action.alert) {}
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

      await store.send(.presentAlert) {
        $0.alert = AlertState {
          TextState("Uh oh!")
        }
      }
      await store.send(.alert(.dismiss)) {
        $0.alert = nil
      }
    }
  }

  @MainActor
  func testInertPresentation_automaticDismissal() async {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      struct Parent: Reducer {
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
        var body: some ReducerOf<Self> {
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
          .ifLet(\.$alert, action: /Action.alert) {}
        }
      }

      let store = TestStore(initialState: Parent.State()) {
        Parent()
      }

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
  }

  @MainActor
  func testPresentation_hydratedDestination_childDismissal() async {
    struct Child: Reducer {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case closeButtonTapped
        case decrementButtonTapped
        case incrementButtonTapped
      }
      @Dependency(\.dismiss) var dismiss
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .closeButtonTapped:
            return .run { _ in
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
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State(child: Child.State())) {
      Parent()
    }

    await store.send(.child(.presented(.closeButtonTapped)))
    await store.receive(.child(.dismiss)) {
      $0.child = nil
    }
  }

  @MainActor
  func testPresentation_rehydratedDestination_childDismissal() async {
    struct ChildFeature: Reducer {
      struct State: Equatable {}
      enum Action: Equatable { case cancel }
      @Dependency(\.dismiss) var dismiss
      var body: some Reducer<State, Action> {
        Reduce { _, action in
          .run { _ in await dismiss() }
        }
      }
    }
    struct ChildContainerFeature: Reducer {
      struct State: Equatable {
        @PresentationState var child: ChildFeature.State?
      }
      enum Action: Equatable {
        case openChild
        case child(PresentationAction<ChildFeature.Action>)
      }
      var body: some Reducer<State, Action> {
        EmptyReducer()
          .ifLet(\.$child, action: /Action.child) {
            ChildFeature()
          }
      }
    }
    struct ParentFeature: Reducer {
      struct State: Equatable {
        var childContainer = ChildContainerFeature.State()
      }
      enum Action: Equatable {
        case childContainer(ChildContainerFeature.Action)
      }
      var body: some Reducer<State, Action> {
        Scope(state: \.childContainer, action: /Action.childContainer) {
          ChildContainerFeature()
        }
        Reduce { state, action in
          switch action {
          case .childContainer(.openChild):
            state.childContainer.child = ChildFeature.State()
            return .none
          default:
            return .none
          }
        }
      }
    }
    let store = TestStore(initialState: ParentFeature.State()) { ParentFeature() }

    await store.send(.childContainer(.openChild)) { state in
      state.childContainer.child = ChildFeature.State()
    }
    await store.send(.childContainer(.child(.presented(.cancel))))
    await store.receive(.childContainer(.child(.dismiss))) { state in
      state.childContainer.child = nil
    }

    await store.send(.childContainer(.openChild)) { state in
      state.childContainer.child = ChildFeature.State()
    }
    await store.send(.childContainer(.child(.presented(.cancel))))
    await store.receive(.childContainer(.child(.dismiss))) { state in
      state.childContainer.child = nil
    }
  }

  @MainActor
  func testEnumPresentation() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
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
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .closeButtonTapped:
              return .run { _ in
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
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var destination: Destination.State?
          var isDeleted = false
        }
        enum Action: Equatable {
          case destination(PresentationAction<Destination.Action>)
          case presentAlert
          case presentChild(id: UUID? = nil)
        }
        @Dependency(\.uuid) var uuid
        var body: some ReducerOf<Self> {
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
          .ifLet(\.$destination, action: /Action.destination) {
            Destination()
          }
        }
        struct Destination: Reducer {
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
          var body: some ReducerOf<Self> {
            Scope(state: /State.alert, action: /Action.alert) {}
            Scope(state: /State.child, action: /Action.child) {
              Child()
            }
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
        $0.uuid = .incrementing
      }

      await store.send(.presentChild()) {
        $0.destination = .child(
          Child.State(id: UUID(0))
        )
      }
      await store.send(.destination(.presented(.child(.startButtonTapped))))
      await clock.advance(by: .seconds(2))
      await store.receive(.destination(.presented(.child(.tick)))) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
          $0.count = 1
        }
      }
      await store.receive(.destination(.presented(.child(.tick)))) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
          $0.count = 2
        }
      }
      await store.send(.destination(.presented(.child(.closeButtonTapped))))
      await store.receive(.destination(.dismiss)) {
        $0.destination = nil
      }
      await store.send(.presentChild()) {
        $0.destination = .child(
          Child.State(id: UUID(1))
        )
      }
      await clock.advance(by: .seconds(2))
      await store.send(.destination(.presented(.child(.startButtonTapped))))
      await clock.advance(by: .seconds(2))
      await store.receive(.destination(.presented(.child(.tick)))) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
          $0.count = 1
        }
      }
      await store.receive(.destination(.presented(.child(.tick)))) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
          $0.count = 2
        }
      }
      await store.send(
        .presentChild(id: UUID(1))
      ) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
          $0.count = 0
        }
      }
      await clock.advance(by: .seconds(2))
      await store.receive(.destination(.presented(.child(.tick)))) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
          $0.count = 1
        }
      }
      await store.receive(.destination(.presented(.child(.tick)))) {
        try (/Parent.Destination.State.child).modify(&$0.destination) {
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

  @MainActor
  func testNavigation_cancelID_childCancellation() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {
        case startButtonTapped
        case stopButtonTapped
      }
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .startButtonTapped:
            return .run { _ in
              try await Task.never()
            }
            .cancellable(id: 42)

          case .stopButtonTapped:
            return .cancel(id: 42)
          }
        }
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }
    let presentationTask = await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.startButtonTapped)))
    await store.send(.child(.presented(.stopButtonTapped)))
    await presentationTask.cancel()
  }

  @MainActor
  func testNavigation_cancelID_parentCancellation() async {
    struct Grandchild: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {
        case startButtonTapped
      }
      enum CancelID { case effect }
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .startButtonTapped:
            return .run { _ in
              try await Task.never()
            }
            .cancellable(id: CancelID.effect)
          }
        }
      }
    }

    struct Child: Reducer {
      struct State: Equatable {
        @PresentationState var grandchild: Grandchild.State?
      }
      enum Action: Equatable {
        case grandchild(PresentationAction<Grandchild.Action>)
        case presentGrandchild
        case startButtonTapped
      }
      enum CancelID { case effect }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .grandchild:
            return .none
          case .presentGrandchild:
            state.grandchild = Grandchild.State()
            return .none
          case .startButtonTapped:
            return .run { _ in
              try await Task.never()
            }
            .cancellable(id: CancelID.effect)
          }
        }
        .ifLet(\.$grandchild, action: /Action.grandchild) {
          Grandchild()
        }
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case stopButtonTapped
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .stopButtonTapped:
            return .merge(
              .cancel(id: Child.CancelID.effect),
              .cancel(id: Grandchild.CancelID.effect)
            )
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }
    let childPresentationTask = await store.send(.presentChild) {
      $0.child = Child.State()
    }
    let grandchildPresentationTask = await store.send(.child(.presented(.presentGrandchild))) {
      $0.child?.grandchild = Grandchild.State()
    }
    await store.send(.child(.presented(.startButtonTapped)))
    await store.send(.child(.presented(.grandchild(.presented(.startButtonTapped)))))
    await store.send(.stopButtonTapped)
    await grandchildPresentationTask.cancel()
    await childPresentationTask.cancel()
  }

  @MainActor
  func testNavigation_cancelID_parentCancelTwoChildren() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case response(Int)
          case startButtonTapped
        }
        enum CancelID { case effect }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case let .response(value):
              state.count = value
              return .none
            case .startButtonTapped:
              return .run { send in
                for await _ in self.clock.timer(interval: .seconds(1)) {
                  await send(.response(42))
                }
              }
              .cancellable(id: CancelID.effect)
            }
          }
        }
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child1: Child.State?
          @PresentationState var child2: Child.State?
        }
        enum Action: Equatable {
          case child1(PresentationAction<Child.Action>)
          case child2(PresentationAction<Child.Action>)
          case stopButtonTapped
          case presentChildren
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child1, .child2:
              return .none
            case .stopButtonTapped:
              return .cancel(id: Child.CancelID.effect)
            case .presentChildren:
              state.child1 = Child.State()
              state.child2 = Child.State()
              return .none
            }
          }
          .ifLet(\.$child1, action: /Action.child1) {
            Child()
          }
          .ifLet(\.$child2, action: /Action.child2) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }
      await store.send(.presentChildren) {
        $0.child1 = Child.State()
        $0.child2 = Child.State()
      }
      await store.send(.child1(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.presented(.response(42)))) {
        $0.child1?.count = 42
      }
      await store.send(.child2(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.presented(.response(42))))
      await store.receive(.child2(.presented(.response(42)))) {
        $0.child2?.count = 42
      }
      await store.send(.stopButtonTapped)
      await clock.run()
      await store.send(.child1(.dismiss)) {
        $0.child1 = nil
      }
      await store.send(.child2(.dismiss)) {
        $0.child2 = nil
      }
    }
  }

  @MainActor
  func testNavigation_cancelID_childCannotCancelSibling() async throws {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable {
          var count = 0
        }
        enum Action: Equatable {
          case response(Int)
          case startButtonTapped
          case stopButtonTapped
        }
        enum CancelID { case effect }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case let .response(value):
              state.count = value
              return .none
            case .startButtonTapped:
              return .run { send in
                for await _ in self.clock.timer(interval: .seconds(1)) {
                  await send(.response(42))
                }
              }
              .cancellable(id: CancelID.effect)
            case .stopButtonTapped:
              return .cancel(id: CancelID.effect)
            }
          }
        }
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child1: Child.State?
          @PresentationState var child2: Child.State?
        }
        enum Action: Equatable {
          case child1(PresentationAction<Child.Action>)
          case child2(PresentationAction<Child.Action>)
          case presentChildren
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child1, .child2:
              return .none
            case .presentChildren:
              state.child1 = Child.State()
              state.child2 = Child.State()
              return .none
            }
          }
          .ifLet(\.$child1, action: /Action.child1) {
            Child()
          }
          .ifLet(\.$child2, action: /Action.child2) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }
      await store.send(.presentChildren) {
        $0.child1 = Child.State()
        $0.child2 = Child.State()
      }
      await store.send(.child1(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.presented(.response(42)))) {
        $0.child1?.count = 42
      }
      await store.send(.child2(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.presented(.response(42))))
      await store.receive(.child2(.presented(.response(42)))) {
        $0.child2?.count = 42
      }

      await store.send(.child1(.presented(.stopButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child2(.presented(.response(42))))

      await store.send(.child2(.presented(.stopButtonTapped)))
      await clock.advance(by: .seconds(1))

      await clock.run()
      await store.send(.child1(.dismiss)) {
        $0.child1 = nil
      }
      await store.send(.child2(.dismiss)) {
        $0.child2 = nil
      }
    }
  }

  @MainActor
  func testNavigation_cancelID_childCannotCancelIdentifiableSibling() async throws {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable, Identifiable {
          let id: UUID
          var count = 0
        }
        enum Action: Equatable {
          case response(Int)
          case startButtonTapped
          case stopButtonTapped
        }
        enum CancelID { case effect }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case let .response(value):
              state.count = value
              return .none
            case .startButtonTapped:
              return .run { send in
                for await _ in self.clock.timer(interval: .seconds(1)) {
                  await send(.response(42))
                }
              }
              .cancellable(id: CancelID.effect)
            case .stopButtonTapped:
              return .cancel(id: CancelID.effect)
            }
          }
        }
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child1: Child.State?
          @PresentationState var child2: Child.State?
        }
        enum Action: Equatable {
          case child1(PresentationAction<Child.Action>)
          case child2(PresentationAction<Child.Action>)
          case presentChildren
        }
        @Dependency(\.uuid) var uuid
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child1, .child2:
              return .none
            case .presentChildren:
              state.child1 = Child.State(id: self.uuid())
              state.child2 = Child.State(id: self.uuid())
              return .none
            }
          }
          .ifLet(\.$child1, action: /Action.child1) {
            Child()
          }
          .ifLet(\.$child2, action: /Action.child2) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
        $0.uuid = .incrementing
      }
      await store.send(.presentChildren) {
        $0.child1 = Child.State(id: UUID(0))
        $0.child2 = Child.State(id: UUID(1))
      }
      await store.send(.child1(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.presented(.response(42)))) {
        $0.child1?.count = 42
      }
      await store.send(.child2(.presented(.startButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child1(.presented(.response(42))))
      await store.receive(.child2(.presented(.response(42)))) {
        $0.child2?.count = 42
      }

      await store.send(.child1(.presented(.stopButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.child2(.presented(.response(42))))

      await store.send(.child2(.presented(.stopButtonTapped)))
      await clock.advance(by: .seconds(1))

      await clock.run()
      await store.send(.child1(.dismiss)) {
        $0.child1 = nil
      }
      await store.send(.child2(.dismiss)) {
        $0.child2 = nil
      }
    }
  }

  @MainActor
  func testNavigation_cancelID_childCannotCancelParent() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Child: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {
          case stopButtonTapped
        }
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .stopButtonTapped:
              return .cancel(id: Parent.CancelID.effect)
            }
          }
        }
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child: Child.State?
          var count = 0
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case presentChild
          case response(Int)
          case startButtonTapped
          case stopButtonTapped
        }
        enum CancelID { case effect }
        @Dependency(\.continuousClock) var clock
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .presentChild:
              state.child = Child.State()
              return .none
            case let .response(value):
              state.count = value
              return .none
            case .startButtonTapped:
              return .run { send in
                try await self.clock.sleep(for: .seconds(1))
                await send(.response(42))
              }
              .cancellable(id: CancelID.effect)
            case .stopButtonTapped:
              return .cancel(id: CancelID.effect)
            }
          }
          .ifLet(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }
      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.startButtonTapped)
      await store.send(.child(.presented(.stopButtonTapped)))
      await clock.advance(by: .seconds(1))
      await store.receive(.response(42)) {
        $0.count = 42
      }
      await store.send(.stopButtonTapped)
      await store.send(.child(.dismiss)) {
        $0.child = nil
      }
    }
  }

  @MainActor
  func testNavigation_cancelID_parentDismissGrandchild() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
      struct Grandchild: Reducer {
        struct State: Equatable {}
        enum Action: Equatable {
          case response(Int)
          case startButtonTapped
        }
        enum CancelID { case effect }
        @Dependency(\.continuousClock) var clock
        var body: some Reducer<State, Action> {
          Reduce { state, action in
            switch action {
            case .response:
              return .none
            case .startButtonTapped:
              return .run { send in
                try await clock.sleep(for: .seconds(0))
                await send(.response(42))
              }
              .cancellable(id: CancelID.effect)
            }
          }
        }
      }

      struct Child: Reducer {
        struct State: Equatable {
          @PresentationState var grandchild: Grandchild.State?
        }
        enum Action: Equatable {
          case grandchild(PresentationAction<Grandchild.Action>)
          case presentGrandchild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .grandchild:
              return .none
            case .presentGrandchild:
              state.grandchild = Grandchild.State()
              return .none
            }
          }
          .ifLet(\.$grandchild, action: /Action.grandchild) {
            Grandchild()
          }
        }
      }

      struct Parent: Reducer {
        struct State: Equatable {
          @PresentationState var child: Child.State?
        }
        enum Action: Equatable {
          case child(PresentationAction<Child.Action>)
          case dismissGrandchild
          case presentChild
        }
        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .child:
              return .none
            case .dismissGrandchild:
              return .send(.child(.presented(.grandchild(.dismiss))))
            case .presentChild:
              state.child = Child.State()
              return .none
            }
          }
          .ifLet(\.$child, action: /Action.child) {
            Child()
          }
        }
      }

      let clock = TestClock()
      let store = TestStore(initialState: Parent.State()) {
        Parent()
      } withDependencies: {
        $0.continuousClock = clock
      }
      await store.send(.presentChild) {
        $0.child = Child.State()
      }
      await store.send(.child(.presented(.presentGrandchild))) {
        $0.child?.grandchild = Grandchild.State()
      }

      await store.send(.child(.presented(.grandchild(.presented(.startButtonTapped)))))
      await clock.advance()
      await store.receive(.child(.presented(.grandchild(.presented(.response(42))))))

      await store.send(.child(.presented(.grandchild(.presented(.startButtonTapped)))))
      await store.send(.dismissGrandchild)
      await store.receive(.child(.presented(.grandchild(.dismiss)))) {
        $0.child?.grandchild = nil
      }
      await store.send(.child(.dismiss)) {
        $0.child = nil
      }
    }
  }

  @MainActor
  func testRuntimeWarn_NilChild_SendDismissAction() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
      }
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          .none
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    XCTExpectFailure {
      $0.compactDescription == """
        An "ifLet" at \
        "ComposableArchitectureTests/PresentationReducerTests.swift:\(#line - 13)" received a \
        presentation action when destination state was absent. …

          Action:
            PresentationReducerTests.Parent.Action.child(.dismiss)

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
        must run before any other reducer sets destination state to "nil". This ensures that \
        destination reducers can handle their actions while their state is still present.

        • This action was sent to the store while destination state was "nil". Make sure that \
        actions for this reducer can only be sent from a view store when state is present, or \
        from effects that start from this reducer. In SwiftUI applications, use a Composable \
        Architecture view modifier like "sheet(store:…)".
        """
    }

    await store.send(.child(.dismiss))
  }

  @MainActor
  func testRuntimeWarn_NilChild_SendChildAction() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {
        case tap
      }
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          .none
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    XCTExpectFailure {
      $0.compactDescription == """
        An "ifLet" at \
        "ComposableArchitectureTests/PresentationReducerTests.swift:\(#line - 13)" received a \
        presentation action when destination state was absent. …

          Action:
            PresentationReducerTests.Parent.Action.child(.presented(.tap))

        This is generally considered an application logic error, and can happen for a few reasons:

        • A parent reducer set destination state to "nil" before this reducer ran. This reducer \
        must run before any other reducer sets destination state to "nil". This ensures that \
        destination reducers can handle their actions while their state is still present.

        • This action was sent to the store while destination state was "nil". Make sure that \
        actions for this reducer can only be sent from a view store when state is present, or \
        from effects that start from this reducer. In SwiftUI applications, use a Composable \
        Architecture view modifier like "sheet(store:…)".
        """
    }

    await store.send(.child(.presented(.tap)))
  }

  @MainActor
  func testRehydrateSameChild_SendDismissAction() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child(.dismiss):
            state.child = Child.State()
            return .none
          default:
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State(child: Child.State())) {
      Parent()
    }

    await store.send(.child(.dismiss)) {
      $0.child = nil
    }
  }

  @MainActor
  func testRehydrateDifferentChild_SendDismissAction() async {
    struct Child: Reducer {
      struct State: Equatable, Identifiable {
        let id: UUID
      }
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
      }
      @Dependency(\.uuid) var uuid
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child(.dismiss):
            if state.child?.id == UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF") {
              state.child = Child.State(id: self.uuid())
            }
            return .none
          default:
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(
      initialState: Parent.State(
        child: Child.State(id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!)
      )
    ) {
      Parent()
    } withDependencies: {
      $0.uuid = .incrementing
    }

    await store.send(.child(.dismiss)) {
      $0.child = Child.State(id: UUID(0))
    }
    await store.send(.child(.dismiss)) {
      $0.child = nil
    }
  }

  @MainActor
  func testPresentation_parentNilsOutChildWithLongLivingEffect() async {
    struct Child: Reducer {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case dismiss
        case dismissMe
        case task
      }
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .dismiss:
            return .send(.dismissMe)
          case .dismissMe:
            return .none
          case .task:
            return .run { _ in
              try await Task.never()
            }
          }
        }
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child(.presented(.dismissMe)):
            state.child = nil
            return .none
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.task)))
    await store.send(.child(.presented(.dismiss)))
    await store.receive(.child(.presented(.dismissMe))) {
      $0.child = nil
    }
  }

  @MainActor
  func testPresentation_DestinationEnum_IdentityChange() async {
    struct Child: Reducer {
      struct State: Equatable, Identifiable {
        var id = DependencyValues._current.uuid()
        var count = 0
      }
      enum Action: Equatable {
        case resetIdentity
        case response
        case tap
      }
      @Dependency(\.mainQueue) var mainQueue
      @Dependency(\.uuid) var uuid
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .resetIdentity:
            state.count = 0
            state.id = self.uuid()
            return .none
          case .response:
            state.count = 999
            return .none
          case .tap:
            state.count += 1
            return .run { send in
              try await self.mainQueue.sleep(for: .seconds(1))
              await send(.response)
            }
          }
        }
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var destination: Destination.State?
      }
      enum Action: Equatable {
        case destination(PresentationAction<Destination.Action>)
        case presentChild1
      }
      struct Destination: Reducer {
        enum State: Equatable {
          case child1(Child.State)
          case child2(Child.State)
        }
        enum Action: Equatable {
          case child1(Child.Action)
          case child2(Child.Action)
        }
        var body: some ReducerOf<Self> {
          Scope(state: /State.child1, action: /Action.child1) { Child() }
          Scope(state: /State.child2, action: /Action.child2) { Child() }
        }
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .destination:
            return .none
          case .presentChild1:
            state.destination = .child1(Child.State())
            return .none
          }
        }
        .ifLet(\.$destination, action: /Action.destination) {
          Destination()
        }
      }
    }

    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: Parent.State()) {
      Parent()
    } withDependencies: {
      $0.uuid = .incrementing
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.presentChild1) {
      $0.destination = .child1(
        Child.State(id: UUID(0))
      )
    }
    await store.send(.destination(.presented(.child1(.tap)))) {
      try (/Parent.Destination.State.child1).modify(&$0.destination) {
        $0.count = 1
      }
    }
    await store.send(.destination(.presented(.child1(.resetIdentity)))) {
      try (/Parent.Destination.State.child1).modify(&$0.destination) {
        $0.id = UUID(1)
        $0.count = 0
      }
    }
    await mainQueue.run()
    await store.send(.destination(.dismiss)) {
      $0.destination = nil
    }
  }

  @MainActor
  func testAlertThenDialog() async {
    if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
      struct Feature: Reducer {
        struct State: Equatable {
          @PresentationState var destination: Destination.State?
        }
        enum Action: Equatable {
          case destination(PresentationAction<Destination.Action>)
          case showAlert
          case showDialog
        }

        struct Destination: Reducer {
          enum State: Equatable {
            case alert(AlertState<AlertDialogAction>)
            case dialog(ConfirmationDialogState<AlertDialogAction>)
          }
          enum Action: Equatable {
            case alert(AlertDialogAction)
            case dialog(AlertDialogAction)
          }
          enum AlertDialogAction {
            case showAlert
            case showDialog
          }
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .destination(.presented(.alert(.showDialog))):
              state.destination = .dialog(
                ConfirmationDialogState {
                  TextState("Hello!")
                } actions: {
                })
              return .none
            case .destination(.presented(.dialog(.showAlert))):
              state.destination = .alert(AlertState { TextState("Hello!") })
              return .none
            case .destination:
              return .none
            case .showAlert:
              state.destination = .alert(Self.alert)
              return .none
            case .showDialog:
              state.destination = .dialog(Self.dialog)
              return .none
            }
          }
          .ifLet(\.$destination, action: /Action.destination) {
            Destination()
          }
        }

        static let alert = AlertState<Destination.AlertDialogAction> {
          TextState("Choose")
        } actions: {
          ButtonState(action: .showAlert) { TextState("Show alert") }
          ButtonState(action: .showDialog) { TextState("Show dialog") }
        }
        static let dialog = ConfirmationDialogState<Destination.AlertDialogAction> {
          TextState("Choose")
        } actions: {
          ButtonState(action: .showAlert) { TextState("Show alert") }
          ButtonState(action: .showDialog) { TextState("Show dialog") }
        }
      }

      let store = TestStore(initialState: Feature.State()) {
        Feature()
      }

      await store.send(.showAlert) {
        $0.destination = .alert(Feature.alert)
      }
      await store.send(.destination(.presented(.alert(.showDialog)))) {
        $0.destination = .dialog(
          ConfirmationDialogState {
            TextState("Hello!")
          } actions: {
          })
      }
      await store.send(.destination(.dismiss)) {
        $0.destination = nil
      }

      await store.send(.showDialog) {
        $0.destination = .dialog(Feature.dialog)
      }
      await store.send(.destination(.presented(.dialog(.showAlert)))) {
        $0.destination = .alert(AlertState { TextState("Hello!") })
      }
      await store.send(.destination(.dismiss)) {
        $0.destination = nil
      }
    }
  }

  @MainActor
  func testPresentation_leaveChildPresented() async {
    struct Child: Reducer {
      struct State: Equatable {}
      enum Action: Equatable {}
      var body: some Reducer<State, Action> {
        EmptyReducer()
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
  }

  @MainActor
  func testPresentation_leaveChildPresented_WithLongLivingEffect() async {
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
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    let line = #line
    await store.send(.child(.presented(.tap)))

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
  func testCancelInFlightEffects() async {
    struct Child: Reducer {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case response(Int)
        case tap
      }
      @Dependency(\.mainQueue) var mainQueue
      struct CancelID: Hashable {}
      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case let .response(value):
            state.count = value
            return .none
          case .tap:
            return .run { send in
              try await mainQueue.sleep(for: .seconds(1))
              await send(.response(42))
            }
            .cancellable(id: CancelID(), cancelInFlight: true)
          }
        }
      }
    }

    struct Parent: Reducer {
      struct State: Equatable {
        @PresentationState var child: Child.State?
        var count = 0
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case presentChild
        case response(Int)
      }
      @Dependency(\.mainQueue) var mainQueue
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .presentChild:
            state.child = Child.State()
            return .run { send in
              try await self.mainQueue.sleep(for: .seconds(2))
              await send(.response(42))
            }
            .cancellable(id: Child.CancelID())
          case let .response(value):
            state.count = value
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }
      }
    }

    let mainQueue = DispatchQueue.test
    let store = TestStore(initialState: .init()) {
      Parent()
    } withDependencies: {
      $0.mainQueue = mainQueue.eraseToAnyScheduler()
    }

    await store.send(.presentChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.tap)))
    await mainQueue.advance(by: .milliseconds(500))
    await store.send(.child(.presented(.tap)))
    await mainQueue.advance(by: .milliseconds(1_000))
    await store.receive(.child(.presented(.response(42)))) {
      $0.child?.count = 42
    }
    await mainQueue.advance(by: .milliseconds(500))
    await store.receive(.response(42)) {
      $0.count = 42
    }
    await store.send(.child(.dismiss)) {
      $0.child = nil
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
        @PresentationState var child: Child.State?
      }
      enum Action: Equatable {
        case child(PresentationAction<Child.Action>)
        case tapAfter
        case tapBefore
        case tapChild
      }
      var body: some ReducerOf<Self> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .tapAfter:
            return .none
          case .tapBefore:
            state.child = nil
            return .none
          case .tapChild:
            return .none
          }
        }

        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .tapAfter:
            return .none
          case .tapBefore:
            return .none
          case .tapChild:
            state.child = Child.State()
            return .none
          }
        }
        .ifLet(\.$child, action: /Action.child) {
          Child()
        }

        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .tapAfter:
            state.child = nil
            return .none
          case .tapBefore:
            return .none
          case .tapChild:
            return .none
          }
        }
      }
    }

    let store = TestStore(initialState: Parent.State()) {
      Parent()
    }

    await store.send(.tapChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.onAppear)))
    await store.send(.tapBefore) {
      $0.child = nil
    }

    await store.send(.tapChild) {
      $0.child = Child.State()
    }
    await store.send(.child(.presented(.onAppear)))
    await store.send(.tapAfter) {
      $0.child = nil
    }
    // NB: Another action needs to come into the `ifLet` to cancel the child action
    await store.send(.tapAfter)
  }

  @MainActor
  func testPresentation_leaveAlertPresentedForNonAlertActions() async {
    if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
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
          @PresentationState var destination: Destination.State?
          var isDeleted = false
        }
        enum Action: Equatable {
          case destination(PresentationAction<Destination.Action>)
          case presentAlert
          case presentChild
        }

        var body: some ReducerOf<Self> {
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
            case .presentChild:
              state.destination = .child(Child.State())
              return .none
            }
          }
          .ifLet(\.$destination, action: /Action.destination) {
            Destination()
          }
        }
        struct Destination: Reducer {
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
          var body: some ReducerOf<Self> {
            Scope(state: /State.alert, action: /Action.alert) {}
            Scope(state: /State.child, action: /Action.child) {
              Child()
            }
          }
        }
      }
      let line = #line - 6

      let store = TestStore(initialState: Parent.State()) {
        Parent()
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

      XCTExpectFailure {
        $0.compactDescription.hasPrefix(
          """
          A "Scope" at "\(#fileID):\(line)" received a child action when child state was set to a \
          different case. …
          """
        )
      }
      await store.send(.destination(.presented(.child(.decrementButtonTapped))))
    }
  }

  @MainActor
  func testFastPathEquality() {
    struct State: Equatable {
      static func == (lhs: Self, rhs: Self) -> Bool {
        Thread.sleep(forTimeInterval: 5)
        return true
      }
    }

    @PresentationState var state = State()
    let start = Date()
    XCTAssertEqual($state, $state)
    XCTAssertLessThan(Date().timeIntervalSince(start), 0.1)
  }

  @MainActor
  func testNestedDismiss() async {
    let store = TestStore(initialState: NestedDismissFeature.State()) {
      NestedDismissFeature()
    }

    await store.send(\.presentButtonTapped) {
      $0.child = NestedDismissFeature.State()
    }
    await store.send(\.child.presentButtonTapped) {
      $0.child?.child = NestedDismissFeature.State()
    }
    await store.send(\.child.child.dismissButtonTapped)
    await store.receive(\.child.child.dismiss) {
      $0.child?.child = nil
    }
  }
}

@Reducer
private struct NestedDismissFeature {
  struct State: Equatable {
    @PresentationState var child: NestedDismissFeature.State?
  }
  enum Action {
    case child(PresentationAction<NestedDismissFeature.Action>)
    case dismissButtonTapped
    case presentButtonTapped
  }
  @Dependency(\.dismiss) var dismiss
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .child:
        return .none
      case .dismissButtonTapped:
        return .run { _ in await dismiss() }
      case .presentButtonTapped:
        state.child = State()
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      Self()
    }
  }
}
