#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import XCTest

  final class ReducerMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        //isRecording: true,
        macros: [ReducerMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testBasics() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          struct State {
          }
          @CasePathable
          enum Action {
          }
          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnumState() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          enum State {
          }
          enum Action {
          }
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          @CasePathable @dynamicMemberLookup
          enum State {
          }
          @CasePathable
          enum Action {
          }
          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testAlreadyApplied() {
      assertMacro {
        """
        @Reducer
        struct Feature: Reducer, Sendable {
          @CasePathable
          @dynamicMemberLookup
          enum State {
          }
          @CasePathable
          enum Action {
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature: Reducer, Sendable {
          @CasePathable
          @dynamicMemberLookup
          enum State {
          }
          @CasePathable
          enum Action {
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      }
    }

    func testExistingCasePathableConformance() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          enum State: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          enum Action: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          @dynamicMemberLookup
          enum State: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          enum Action: CasePathable {
            struct AllCasePaths {}
            static var allCasePaths: AllCasePaths { AllCasePaths() }
          }
          @ReducerBuilder<State, Action>
          var body: some ReducerOf<Self> {
            EmptyReducer()
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testReduceMethodDiagnostic() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          func reduce(into state: inout State, action: Action) -> EffectOf<Self> {
            .none
          }
          var body: some ReducerOf<Self> {
            Reduce(reduce)
            Reduce(reduce(into:action:))
            Reduce(self.reduce)
            Reduce(self.reduce(into:action:))
            Reduce(AnotherReducer().reduce)
            Reduce(AnotherReducer().reduce(into:action:))
          }
        }
        """
      } diagnostics: {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          func reduce(into state: inout State, action: Action) -> EffectOf<Self> {
               ┬─────
               ╰─ 🛑 A 'reduce' method should not be defined in a reducer with a 'body'; it takes precedence and 'body' will never be invoked
            .none
          }
          var body: some ReducerOf<Self> {
            Reduce(reduce)
            Reduce(reduce(into:action:))
            Reduce(self.reduce)
            Reduce(self.reduce(into:action:))
            Reduce(AnotherReducer().reduce)
            Reduce(AnotherReducer().reduce(into:action:))
          }
        }
        """
      }
    }

    func testEmptyEnum() {
      assertMacro {
        """
        @Reducer
        enum Destination {}
        """
      } expansion: {
        """
        enum Destination {

            @CasePathable
            @dynamicMemberLookup
            @ObservableState
            enum State: ComposableArchitecture.CaseReducerState {
                typealias StateReducer = Destination

            }

            @CasePathable
            enum Action {

            }

            @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
            static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {

            ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()

            }

            enum CaseScope {

            }

            static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
                switch store.state {

                }
            }}

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnum() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case activity(Activity)
          case timeline(Timeline)
          case tweet(Tweet)
          case alert(AlertState<Alert>)

          enum Alert {
            case ok
          }
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case activity(Activity)
          case timeline(Timeline)
          case tweet(Tweet)
          @ReducerCaseEphemeral
          case alert(AlertState<Alert>)

          enum Alert {
            case ok
          }

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case activity(Activity.State)
            case timeline(Timeline.State)
            case tweet(Tweet.State)
            case alert(AlertState<Alert>)
          }

          @CasePathable
          enum Action {
            case activity(Activity.Action)
            case timeline(Timeline.Action)
            case tweet(Tweet.Action)
            case alert(AlertState<Alert>.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Activity>, ComposableArchitecture.Scope<Self.State, Self.Action, Timeline>>, ComposableArchitecture.Scope<Self.State, Self.Action, Tweet>> {

          ComposableArchitecture.Scope(state: \Self.State.Cases.activity, action: \Self.Action.Cases.activity) {
          Activity()
          }
          ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
          Timeline()
          }
          ComposableArchitecture.Scope(state: \Self.State.Cases.tweet, action: \Self.Action.Cases.tweet) {
          Tweet()
          }

          }

          enum CaseScope {
            case activity(ComposableArchitecture.StoreOf<Activity>)
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case tweet(ComposableArchitecture.StoreOf<Tweet>)
            case alert(AlertState<Alert>)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .activity:
              return .activity(store.scope(state: \.activity, action: \.activity)!)
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            case .tweet:
              return .tweet(store.scope(state: \.tweet, action: \.tweet)!)
            case let .alert(v0):
              return .alert(v0)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """#
      }
    }

    func testEnum_Empty() {
      assertMacro {
        """
        @Reducer
        enum Destination {
        }
        """
      } expansion: {
        """
        enum Destination {

            @CasePathable
            @dynamicMemberLookup
            @ObservableState
            enum State: ComposableArchitecture.CaseReducerState {
                typealias StateReducer = Destination

            }

            @CasePathable
            enum Action {

            }

            @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
            static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {

            ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()

            }

            enum CaseScope {

            }

            static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
                switch store.state {

                }
            }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnum_OneAlertCase() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case alert(AlertState<Never>)
        }
        """
      } expansion: {
        """
        enum Destination {
          @ReducerCaseEphemeral
          case alert(AlertState<Never>)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case alert(AlertState<Never>)
          }

          @CasePathable
          enum Action {
            case alert(AlertState<Never>.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {

          ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()

          }

          enum CaseScope {
            case alert(AlertState<Never>)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case let .alert(v0):
              return .alert(v0)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnum_TwoCases() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case activity(Activity)
          case timeline(Timeline)
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case activity(Activity)
          case timeline(Timeline)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case activity(Activity.State)
            case timeline(Timeline.State)
          }

          @CasePathable
          enum Action {
            case activity(Activity.Action)
            case timeline(Timeline.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Activity>, ComposableArchitecture.Scope<Self.State, Self.Action, Timeline>> {

          ComposableArchitecture.Scope(state: \Self.State.Cases.activity, action: \Self.Action.Cases.activity) {
          Activity()
          }
          ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
          Timeline()
          }

          }

          enum CaseScope {
            case activity(ComposableArchitecture.StoreOf<Activity>)
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .activity:
              return .activity(store.scope(state: \.activity, action: \.activity)!)
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """#
      }
    }

    func testEnum_CaseIgnored() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case timeline(Timeline)
          @ReducerCaseIgnored
          case meeting(Meeting)
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case timeline(Timeline)
          @ReducerCaseIgnored
          case meeting(Meeting)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case timeline(Timeline.State)
            case meeting(Meeting)
          }

          @CasePathable
          enum Action {
            case timeline(Timeline.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.Scope<Self.State, Self.Action, Timeline> {

          ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
          Timeline()
          }

          }

          enum CaseScope {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case meeting(Meeting)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            case let .meeting(v0):
              return .meeting(v0)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """#
      }
    }

    func testEnum_Attributes() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case alert(AlertState<Alert>)
          case dialog(ConfirmationDialogState<Dialog>)
          case meeting(Meeting, syncUp: SyncUp)
        }
        """
      } expansion: {
        """
        enum Destination {
          @ReducerCaseEphemeral
          case alert(AlertState<Alert>)
          @ReducerCaseEphemeral
          case dialog(ConfirmationDialogState<Dialog>)
          @ReducerCaseIgnored
          case meeting(Meeting, syncUp: SyncUp)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case alert(AlertState<Alert>)
            case dialog(ConfirmationDialogState<Dialog>)
            case meeting(Meeting, syncUp: SyncUp)
          }

          @CasePathable
          enum Action {
            case alert(AlertState<Alert>.Action)
            case dialog(ConfirmationDialogState<Dialog>.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {

          ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()

          }

          enum CaseScope {
            case alert(AlertState<Alert>)
            case dialog(ConfirmationDialogState<Dialog>)
            case meeting(Meeting, syncUp: SyncUp)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case let .alert(v0):
              return .alert(v0)
            case let .dialog(v0):
              return .dialog(v0)
            case let .meeting(v0, v1):
              return .meeting(v0, syncUp: v1)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnum_Conformances() {
      assertMacro {
        """
        @Reducer(state: .equatable)
        enum Destination {
          case drillDown(Counter)
          case popover(Counter)
          case sheet(Counter)
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case drillDown(Counter)
          case popover(Counter)
          case sheet(Counter)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState, Equatable {
            typealias StateReducer = Destination
            case drillDown(Counter.State)
            case popover(Counter.State)
            case sheet(Counter.State)
          }

          @CasePathable
          enum Action {
            case drillDown(Counter.Action)
            case popover(Counter.Action)
            case sheet(Counter.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Counter>, ComposableArchitecture.Scope<Self.State, Self.Action, Counter>>, ComposableArchitecture.Scope<Self.State, Self.Action, Counter>> {

          ComposableArchitecture.Scope(state: \Self.State.Cases.drillDown, action: \Self.Action.Cases.drillDown) {
          Counter()
          }
          ComposableArchitecture.Scope(state: \Self.State.Cases.popover, action: \Self.Action.Cases.popover) {
          Counter()
          }
          ComposableArchitecture.Scope(state: \Self.State.Cases.sheet, action: \Self.Action.Cases.sheet) {
          Counter()
          }

          }

          enum CaseScope {
            case drillDown(ComposableArchitecture.StoreOf<Counter>)
            case popover(ComposableArchitecture.StoreOf<Counter>)
            case sheet(ComposableArchitecture.StoreOf<Counter>)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .drillDown:
              return .drillDown(store.scope(state: \.drillDown, action: \.drillDown)!)
            case .popover:
              return .popover(store.scope(state: \.popover, action: \.popover)!)
            case .sheet:
              return .sheet(store.scope(state: \.sheet, action: \.sheet)!)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """#
      }
    }

    func testEnum_Nested() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case feature(Nested.Feature)
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case feature(Nested.Feature)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case feature(Nested.Feature.State)
          }

          @CasePathable
          enum Action {
            case feature(Nested.Feature.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.Scope<Self.State, Self.Action, Nested.Feature> {

          ComposableArchitecture.Scope(state: \Self.State.Cases.feature, action: \Self.Action.Cases.feature) {
          Nested.Feature()
          }

          }

          enum CaseScope {
            case feature(ComposableArchitecture.StoreOf<Nested.Feature>)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .feature:
              return .feature(store.scope(state: \.feature, action: \.feature)!)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """#
      }
    }

    func testStructWithNoRequirements() {
      assertMacro {
        """
        @Reducer
        struct Feature {
        }
        """
      } expansion: {
        """
        struct Feature {

            @ObservableState
            struct State: Codable, Equatable, Hashable, Sendable {
                init() {
                }
            }

            enum Action: Equatable, Hashable, Sendable {
            }

            let body = ComposableArchitecture.EmptyReducer<State, Action>()
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testStructWithNoRequirements_AccessControl() {
      assertMacro {
        """
        @Reducer
        public struct Feature {
        }
        """
      } expansion: {
        """
        public struct Feature {

            @ObservableState

            public struct State: Codable, Equatable, Hashable, Sendable {

                public init() {
                }
            }

            public enum Action: Equatable, Hashable, Sendable {
            }

            public let body = ComposableArchitecture.EmptyReducer<State, Action>()
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testFilledRequirements_Typealias() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          typealias State = Int
          typealias Action = Bool
        }
        """
      } expansion: {
        """
        struct Feature {
          typealias State = Int
          typealias Action = Bool

          let body = ComposableArchitecture.EmptyReducer<State, Action>()
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testFilledRequirements_BodyWithTypes() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          var body: some Reducer<Int, Bool> { EmptyReducer() }
        }
        """
      } expansion: {
        """
        struct Feature {
          @ComposableArchitecture.ReducerBuilder<Int, Bool>
          var body: some Reducer<Int, Bool> { EmptyReducer() }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testFilledRequirements_ReducerOf() {
      assertMacro {
        #"""
        @Reducer
        struct Feature {
          var body: some ReducerOf<Base> { EmptyReducer() }
        }
        """#
      } expansion: {
        """
        struct Feature {
          @ComposableArchitecture.ReducerBuilder<Base.State, Base.Action>
          var body: some ReducerOf<Base> { EmptyReducer() }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testFilledRequirements_ReduceMethod() {
      assertMacro {
        """
        @Reducer
        struct Feature {
          func reduce(into state: inout Base.State, action: Base.Action) -> EffectOf<Base> {
            .none
          }
        }
        """
      } expansion: {
        """
        struct Feature {
          func reduce(into state: inout Base.State, action: Base.Action) -> EffectOf<Base> {
            .none
          }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testFilledRequirements_LetBody() {
      assertMacro {
        """
        @Reducer
        struct Empty {
          let body = EmptyReducer<State, Action>()
        }
        """
      } expansion: {
        """
        struct Empty {
          let body = EmptyReducer<State, Action>()
        }

        extension Empty: ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testAvailability() {
      assertMacro {
        """
        @available(iOS, unavailable)
        @Reducer
        struct Feature {}
        """
      } expansion: {
        """
        @available(iOS, unavailable)
        struct Feature {

            @ObservableState
            struct State: Codable, Equatable, Hashable, Sendable {
                init() {
                }
            }

            enum Action: Equatable, Hashable, Sendable {
            }

            let body = ComposableArchitecture.EmptyReducer<State, Action>()}

        @available(iOS, unavailable) extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }
  }
#endif
