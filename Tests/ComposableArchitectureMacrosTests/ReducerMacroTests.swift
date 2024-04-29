#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import XCTest

  final class ReducerMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        // isRecording: true,
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
            case alert(AlertState<Alert> .Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action> ._Sequence<ComposableArchitecture.ReducerBuilder<Self.State, Self.Action> ._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Activity>, ComposableArchitecture.Scope<Self.State, Self.Action, Timeline>>, ComposableArchitecture.Scope<Self.State, Self.Action, Tweet>> {
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

    func testEnum_DefaultInitializer() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          case timeline(Timeline)
          case meeting(Meeting = Meeting(context: .sheet))
        }
        """
      } expansion: {
        #"""
        enum Destination {
          case timeline(Timeline)
          case meeting(Meeting = Meeting(context: .sheet))

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case timeline(Timeline.State)
            case meeting(Meeting.State)
          }

          @CasePathable
          enum Action {
            case timeline(Timeline.Action)
            case meeting(Meeting.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Timeline>, ComposableArchitecture.Scope<Self.State, Self.Action, Meeting>> {
            ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
              Timeline()
            }
            ComposableArchitecture.Scope(state: \Self.State.Cases.meeting, action: \Self.Action.Cases.meeting) {
              Meeting(context: .sheet)
            }
          }

          enum CaseScope {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case meeting(ComposableArchitecture.StoreOf<Meeting>)
          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            case .meeting:
              return .meeting(store.scope(state: \.meeting, action: \.meeting)!)
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

    func testEnum_Empty_AccessControl_Package() {
      assertMacro {
        """
        @Reducer
        package enum Destination {
        }
        """
      } expansion: {
        """
        package enum Destination {

            @CasePathable
            @dynamicMemberLookup
            @ObservableState

            package enum State: ComposableArchitecture.CaseReducerState {

                package typealias StateReducer = Destination

            }

            @CasePathable

            package enum Action {

            }

            @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>

            package static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {
                ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
            }

            package enum CaseScope {

            }

            package static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
                switch store.state {

                }
            }
        }

        extension Destination: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """
      }
    }

    func testEnum_Empty_AccessControl_Public() {
      assertMacro {
        """
        @Reducer
        public enum Destination {
        }
        """
      } expansion: {
        """
        public enum Destination {

            @CasePathable
            @dynamicMemberLookup
            @ObservableState

            public enum State: ComposableArchitecture.CaseReducerState {

                public typealias StateReducer = Destination

            }

            @CasePathable

            public enum Action {

            }

            @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>

            public static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {
                ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
            }

            public enum CaseScope {

            }

            public static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
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
            case alert(AlertState<Never> .Action)
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
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action> ._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Activity>, ComposableArchitecture.Scope<Self.State, Self.Action, Timeline>> {
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
            case meeting(Swift.Never)
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
            case alert(AlertState<Alert> .Action)
            case dialog(ConfirmationDialogState<Dialog> .Action)
            case meeting(Swift.Never)
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
          static var body: ComposableArchitecture.ReducerBuilder<Self.State, Self.Action> ._Sequence<ComposableArchitecture.ReducerBuilder<Self.State, Self.Action> ._Sequence<ComposableArchitecture.Scope<Self.State, Self.Action, Counter>, ComposableArchitecture.Scope<Self.State, Self.Action, Counter>>, ComposableArchitecture.Scope<Self.State, Self.Action, Counter>> {
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

    func testEnum_IfConfig() {
      assertMacro {
        """
        @Reducer
        enum Feature {
          case child(ChildFeature)

          #if os(macOS)
            case mac(MacFeature)
            case macAlert(AlertState<MacAlert>)
          #elseif os(iOS)
            case phone(PhoneFeature)
          #else
            case other(OtherFeature)
            case another
          #endif

          #if DEBUG
            #if INNER
              case inner(InnerFeature)
              case innerDialog(ConfirmationDialogState<InnerDialog>)
            #endif
          #endif
        }
        """
      } expansion: {
        #"""
        enum Feature {
          case child(ChildFeature)

          #if os(macOS)
            case mac(MacFeature)
            case macAlert(AlertState<MacAlert>)
          #elseif os(iOS)
            case phone(PhoneFeature)
          #else
            case other(OtherFeature)
            case another
          #endif

          #if DEBUG
            #if INNER
              case inner(InnerFeature)
              case innerDialog(ConfirmationDialogState<InnerDialog>)
            #endif
          #endif

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Feature
            case child(ChildFeature.State)
            #if os(macOS)
            case mac(MacFeature.State)
            case macAlert(AlertState<MacAlert>)
            #elseif os(iOS)
            case phone(PhoneFeature.State)
            #else
            case other(OtherFeature.State)
            case another
            #endif

            #if DEBUG
            #if INNER
            case inner(InnerFeature.State)
            case innerDialog(ConfirmationDialogState<InnerDialog>)
            #endif
            #endif

          }

          @CasePathable
          enum Action {
            case child(ChildFeature.Action)
            #if os(macOS)
            case mac(MacFeature.Action)
            case macAlert(AlertState<MacAlert> .Action)
            #elseif os(iOS)
            case phone(PhoneFeature.Action)
            #else
            case other(OtherFeature.Action)
            case another(Swift.Never)
            #endif

            #if DEBUG
            #if INNER
            case inner(InnerFeature.Action)
            case innerDialog(ConfirmationDialogState<InnerDialog> .Action)
            #endif
            #endif

          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.CombineReducers {
                ComposableArchitecture.Scope(state: \Self.State.Cases.child, action: \Self.Action.Cases.child) {
                  ChildFeature()
                }
                #if os(macOS)
                ComposableArchitecture.Scope(state: \Self.State.Cases.mac, action: \Self.Action.Cases.mac) {
                  MacFeature()
                }
                #elseif os(iOS)
                ComposableArchitecture.Scope(state: \Self.State.Cases.phone, action: \Self.Action.Cases.phone) {
                  PhoneFeature()
                }
                #else
                ComposableArchitecture.Scope(state: \Self.State.Cases.other, action: \Self.Action.Cases.other) {
                  OtherFeature()
                }
                #endif

                #if DEBUG
                #if INNER
                ComposableArchitecture.Scope(state: \Self.State.Cases.inner, action: \Self.Action.Cases.inner) {
                  InnerFeature()
                }
                #endif

                #endif

              }
            )
          }

          enum CaseScope {
            case child(ComposableArchitecture.StoreOf<ChildFeature>)
            #if os(macOS)
            case mac(ComposableArchitecture.StoreOf<MacFeature>)
            case macAlert(AlertState<MacAlert>)
            #elseif os(iOS)
            case phone(ComposableArchitecture.StoreOf<PhoneFeature>)
            #else
            case other(ComposableArchitecture.StoreOf<OtherFeature>)
            case another
            #endif

            #if DEBUG
            #if INNER
            case inner(ComposableArchitecture.StoreOf<InnerFeature>)
            case innerDialog(ConfirmationDialogState<InnerDialog>)
            #endif
            #endif

          }

          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .child:
              return .child(store.scope(state: \.child, action: \.child)!)
            #if os(macOS)
            case .mac:
              return .mac(store.scope(state: \.mac, action: \.mac)!)
            case let .macAlert(v0):
              return .macAlert(v0)
            #elseif os(iOS)
            case .phone:
              return .phone(store.scope(state: \.phone, action: \.phone)!)
            #else
            case .other:
              return .other(store.scope(state: \.other, action: \.other)!)
            case .another:
              return .another
            #endif

            #if DEBUG
            #if INNER
            case .inner:
              return .inner(store.scope(state: \.inner, action: \.inner)!)
            case let .innerDialog(v0):
              return .innerDialog(v0)
            #endif
            #endif

            }
          }
        }

        extension Feature: ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer {
        }
        """#
      }
    }
  }
#endif
