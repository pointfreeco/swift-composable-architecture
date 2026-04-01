#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import XCTest

  final class ReducerMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        // record: .failed,
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
               ╰─ ⚠️ 'reduce(into:action:)' is deprecated: Reducers should be defined using the 'body' property and a 'Reduce'.
                  ✏️ Use 'body' instead
            .none
          }
        }
        """
      } fixes: {
        """
        @Reducer
        struct Feature {
          struct State {
          }
          enum Action {
          }
          var body: some Reducer<State, Action> {
        Reduce { state, action in
        .none
        }
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
          @ComposableArchitecture.ReducerBuilder<State, Action>
          var body: some Reducer<State, Action> {
        Reduce { state, action in
        .none
        }
        }
        }

        extension Feature: ComposableArchitecture.Reducer {
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

            @dynamicMemberLookup
            enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {

                struct AllCasePaths {

                }
                static var allCasePaths: AllCasePaths {
                    AllCasePaths()
                }
            }

            @preconcurrency @MainActor
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
            case alert(Alert)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.activity, action: \Self.Action.Cases.activity) {
                Activity()
              }
              .ifCaseLet(\Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
              .ifCaseLet(\Self.State.Cases.tweet, action: \Self.Action.Cases.tweet) {
                Tweet()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case activity(ComposableArchitecture.StoreOf<Activity>)
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case tweet(ComposableArchitecture.StoreOf<Tweet>)
            case alert(AlertState<Alert>)
            struct AllCasePaths {
              var activity: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Activity>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.activity,
                  extract: {
                    guard case let .activity(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var timeline: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Timeline>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.timeline,
                  extract: {
                    guard case let .timeline(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var tweet: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Tweet>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.tweet,
                  extract: {
                    guard case let .tweet(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var alert: CasePaths.AnyCasePath<CaseScope, AlertState<Alert>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.alert,
                  extract: {
                    guard case let .alert(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
              .ifCaseLet(\Self.State.Cases.meeting, action: \Self.Action.Cases.meeting) {
                Meeting(context: .sheet)
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case meeting(ComposableArchitecture.StoreOf<Meeting>)
            struct AllCasePaths {
              var timeline: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Timeline>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.timeline,
                  extract: {
                    guard case let .timeline(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var meeting: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Meeting>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.meeting,
                  extract: {
                    guard case let .meeting(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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

            @dynamicMemberLookup
            enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {

                struct AllCasePaths {

                }
                static var allCasePaths: AllCasePaths {
                    AllCasePaths()
                }
            }

            @preconcurrency @MainActor
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

            @dynamicMemberLookup

            package enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {


                package struct AllCasePaths {

                }

                package static var allCasePaths: AllCasePaths {
                    AllCasePaths()
                }
            }

            @preconcurrency @MainActor

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

            @dynamicMemberLookup

            public enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {


                public struct AllCasePaths {

                }

                public static var allCasePaths: AllCasePaths {
                    AllCasePaths()
                }
            }

            @preconcurrency @MainActor

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
            case alert(Never)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {
            ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case alert(AlertState<Never>)
            struct AllCasePaths {
              var alert: CasePaths.AnyCasePath<CaseScope, AlertState<Never>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.alert,
                  extract: {
                    guard case let .alert(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.activity, action: \Self.Action.Cases.activity) {
                Activity()
              }
              .ifCaseLet(\Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case activity(ComposableArchitecture.StoreOf<Activity>)
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            struct AllCasePaths {
              var activity: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Activity>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.activity,
                  extract: {
                    guard case let .activity(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var timeline: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Timeline>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.timeline,
                  extract: {
                    guard case let .timeline(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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

    func testEnum_TwoCases_AccessControl_Public() {
      assertMacro {
        """
        @Reducer
        public enum Destination {
          case activity(Activity)
          case timeline(Timeline)
        }
        """
      } expansion: {
        #"""
        public enum Destination {
          case activity(Activity)
          case timeline(Timeline)

          @CasePathable
          @dynamicMemberLookup
          @ObservableState

          public enum State: ComposableArchitecture.CaseReducerState {

            public typealias StateReducer = Destination
            case activity(Activity.State)
            case timeline(Timeline.State)
          }

          @CasePathable

          public enum Action {
            case activity(Activity.Action)
            case timeline(Timeline.Action)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>

          public static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.activity, action: \Self.Action.Cases.activity) {
                Activity()
              }
              .ifCaseLet(\Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
            )
          }

          @dynamicMemberLookup

          public enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case activity(ComposableArchitecture.StoreOf<Activity>)
            case timeline(ComposableArchitecture.StoreOf<Timeline>)

            public struct AllCasePaths {
              public var activity: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Activity>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.activity,
                  extract: {
                    guard case let .activity(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              public var timeline: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Timeline>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.timeline,
                  extract: {
                    guard case let .timeline(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }

            public static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor

          public static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
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
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case meeting(Meeting)
            struct AllCasePaths {
              var timeline: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Timeline>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.timeline,
                  extract: {
                    guard case let .timeline(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var meeting: CasePaths.AnyCasePath<CaseScope, Meeting> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.meeting,
                  extract: {
                    guard case let .meeting(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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

    func testEnum_CaseIgnoredExplicitActions() {
      assertMacro {
        """
        @Reducer
        enum Destination {
          @ReducerCaseIgnored case alert(AlertState<Alert>)
          case settings(Settings)

          enum Action {
            case alert(Alert)
            case settings(Settings.Action)
          }
        }
        """
      } expansion: {
        #"""
        enum Destination {
          @ReducerCaseIgnored
          @ReducerCaseEphemeral case alert(AlertState<Alert>)
          case settings(Settings)
          @CasePathable

          enum Action {
            case alert(Alert)
            case settings(Settings.Action)
          }

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Destination
            case alert(AlertState<Alert>)
            case settings(Settings.State)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.settings, action: \Self.Action.Cases.settings) {
                Settings()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case alert(ComposableArchitecture.Store<AlertState<Alert>, Alert>)
            case settings(ComposableArchitecture.StoreOf<Settings>)
            struct AllCasePaths {
              var alert: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.Store<AlertState<Alert>, Alert>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.alert,
                  extract: {
                    guard case let .alert(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var settings: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Settings>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.settings,
                  extract: {
                    guard case let .settings(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .alert:
              return .alert(store.scope(state: \.alert, action: \.alert)!)
            case .settings:
              return .settings(store.scope(state: \.settings, action: \.settings)!)
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
            case alert(Alert)
            case dialog(Dialog)
            case meeting(Swift.Never)
          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: ComposableArchitecture.EmptyReducer<Self.State, Self.Action> {
            ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case alert(AlertState<Alert>)
            case dialog(ConfirmationDialogState<Dialog>)
            case meeting(Meeting, syncUp: SyncUp)
            struct AllCasePaths {
              var alert: CasePaths.AnyCasePath<CaseScope, AlertState<Alert>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.alert,
                  extract: {
                    guard case let .alert(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var dialog: CasePaths.AnyCasePath<CaseScope, ConfirmationDialogState<Dialog>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.dialog,
                  extract: {
                    guard case let .dialog(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }

            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.drillDown, action: \Self.Action.Cases.drillDown) {
                Counter()
              }
              .ifCaseLet(\Self.State.Cases.popover, action: \Self.Action.Cases.popover) {
                Counter()
              }
              .ifCaseLet(\Self.State.Cases.sheet, action: \Self.Action.Cases.sheet) {
                Counter()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case drillDown(ComposableArchitecture.StoreOf<Counter>)
            case popover(ComposableArchitecture.StoreOf<Counter>)
            case sheet(ComposableArchitecture.StoreOf<Counter>)
            struct AllCasePaths {
              var drillDown: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Counter>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.drillDown,
                  extract: {
                    guard case let .drillDown(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var popover: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Counter>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.popover,
                  extract: {
                    guard case let .popover(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var sheet: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Counter>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.sheet,
                  extract: {
                    guard case let .sheet(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.feature, action: \Self.Action.Cases.feature) {
                Nested.Feature()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case feature(ComposableArchitecture.StoreOf<Nested.Feature>)
            struct AllCasePaths {
              var feature: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<Nested.Feature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.feature,
                  extract: {
                    guard case let .feature(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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

            let body = ComposableArchitecture.EmptyReducer<State, Action>()
        }

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
            case macAlert(MacAlert)
            #elseif os(iOS)
            case phone(PhoneFeature.Action)
            #else
            case other(OtherFeature.Action)
            case another(Swift.Never)
            #endif

            #if DEBUG
            #if INNER
            case inner(InnerFeature.Action)
            case innerDialog(InnerDialog)
            #endif
            #endif

          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.child, action: \Self.Action.Cases.child) {
                ChildFeature()
              }
              #if os(macOS)
              .ifCaseLet(\Self.State.Cases.mac, action: \Self.Action.Cases.mac) {
                MacFeature()
              }
              #elseif os(iOS)
              .ifCaseLet(\Self.State.Cases.phone, action: \Self.Action.Cases.phone) {
                PhoneFeature()
              }
              #else
              .ifCaseLet(\Self.State.Cases.other, action: \Self.Action.Cases.other) {
                OtherFeature()
              }
              #endif

              #if DEBUG
              #if INNER
              .ifCaseLet(\Self.State.Cases.inner, action: \Self.Action.Cases.inner) {
                InnerFeature()
              }
              #endif
              #endif

            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
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

            struct AllCasePaths {
              var child: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<ChildFeature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.child,
                  extract: {
                    guard case let .child(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              #if os(macOS)
              var mac: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<MacFeature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.mac,
                  extract: {
                    guard case let .mac(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var macAlert: CasePaths.AnyCasePath<CaseScope, AlertState<MacAlert>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.macAlert,
                  extract: {
                    guard case let .macAlert(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              #elseif os(iOS)
              var phone: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<PhoneFeature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.phone,
                  extract: {
                    guard case let .phone(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              #else
              var other: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<OtherFeature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.other,
                  extract: {
                    guard case let .other(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var another: CasePaths.AnyCasePath<CaseScope, Void> {
                CasePaths.AnyCasePath(
                  embed: {
                    CaseScope.another
                  },
                  extract: {
                    guard case .another = $0 else {
                      return nil
                    };
                    return ()
                  }
                )
              }
              #endif

              #if DEBUG
              #if INNER
              var inner: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<InnerFeature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.inner,
                  extract: {
                    guard case let .inner(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              var innerDialog: CasePaths.AnyCasePath<CaseScope, ConfirmationDialogState<InnerDialog>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.innerDialog,
                  extract: {
                    guard case let .innerDialog(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }
              #endif
              #endif

            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
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

    func testEnum_IfConfigPrunesEmptyBranches() {
      assertMacro {
        """
        @Reducer
        enum Feature {
          case child(ChildFeature)

          #if DEBUG
            case value(Int, String)
          #endif
        }
        """
      } expansion: {
        #"""
        enum Feature {
          case child(ChildFeature)

          #if DEBUG
            case value(Int, String)
          #endif

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: ComposableArchitecture.CaseReducerState {
            typealias StateReducer = Feature
            case child(ChildFeature.State)
            #if DEBUG
            case value(Int, String)
            #endif

          }

          @CasePathable
          enum Action {
            case child(ChildFeature.Action)
            #if DEBUG
            case value(Swift.Never)
            #endif

          }

          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          static var body: Reduce<Self.State, Self.Action> {
            ComposableArchitecture.Reduce(
              ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
              .ifCaseLet(\Self.State.Cases.child, action: \Self.Action.Cases.child) {
                ChildFeature()
              }
            )
          }

          @dynamicMemberLookup
          enum CaseScope: ComposableArchitecture._CaseScopeProtocol, CasePaths.CasePathable {
            case child(ComposableArchitecture.StoreOf<ChildFeature>)
            #if DEBUG
            case value(Int, String)
            #endif

            struct AllCasePaths {
              var child: CasePaths.AnyCasePath<CaseScope, ComposableArchitecture.StoreOf<ChildFeature>> {
                CasePaths.AnyCasePath(
                  embed: CaseScope.child,
                  extract: {
                    guard case let .child(v0) = $0 else {
                      return nil
                    };
                    return v0
                  }
                )
              }

            }
            static var allCasePaths: AllCasePaths {
              AllCasePaths()
            }
          }

          @preconcurrency @MainActor
          static func scope(_ store: ComposableArchitecture.Store<Self.State, Self.Action>) -> CaseScope {
            switch store.state {
            case .child:
              return .child(store.scope(state: \.child, action: \.child)!)
            #if DEBUG
            case let .value(v0, v1):
              return .value(v0, v1)
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
