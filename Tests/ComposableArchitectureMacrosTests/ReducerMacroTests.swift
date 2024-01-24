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

    func testEnum() {
      assertMacro(record: true) {
        """
        @Reducer
        enum Destination {
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
          case timeline(Timeline)
          case tweet(Tweet)
          case alert(AlertState<Alert>)

          enum Alert {
            case ok
          }

          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          enum State: CaseReducerState, Equatable {
            typealias Reducer = Destination
            case timeline(Timeline.State)
            case tweet(Tweet.State)
            case alert(AlertState<Alert>.State)
          }

          @CasePathable
          enum Action {
            case timeline(Timeline.Action)
            case tweet(Tweet.Action)
            case alert(AlertState<Alert>.Action)
          }

          static var body: some ComposableArchitecture.Reducer<Self.State, Self.Action> {
            CombineReducers {
              ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
              ComposableArchitecture.Scope(state: \Self.State.Cases.tweet, action: \Self.Action.Cases.tweet) {
                Tweet()
              }
              ComposableArchitecture.Scope(state: \Self.State.Cases.alert, action: \Self.Action.Cases.alert) {
                AlertState()
              }
            }
          }

          enum Cases {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case tweet(ComposableArchitecture.StoreOf<Tweet>)
            case alert(ComposableArchitecture.StoreOf<AlertState<Alert>>)
          }

          static func cases(_ store: Store<Self.State, Self.Action>) -> Cases {
            switch store.state {
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            case .tweet:
              return .tweet(store.scope(state: \.tweet, action: \.tweet)!)
            case .alert:
              return .alert(store.scope(state: \.alert, action: \.alert)!)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer {
        }
        """#
      }
    }

    func testEnum_CaseIgnored() {
      assertMacro(record: true) {
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
          enum State: CaseReducerState, Equatable {
            typealias Reducer = Destination
            case timeline(Timeline.State)
            case meeting(Meeting)
          }

          @CasePathable
          enum Action {
            case timeline(Timeline.Action)
          }

          static var body: some ComposableArchitecture.Reducer<Self.State, Self.Action> {
            CombineReducers {
              ComposableArchitecture.Scope(state: \Self.State.Cases.timeline, action: \Self.Action.Cases.timeline) {
                Timeline()
              }
            }
          }

          enum Cases {
            case timeline(ComposableArchitecture.StoreOf<Timeline>)
            case meeting(Meeting)
          }

          static func cases(_ store: Store<Self.State, Self.Action>) -> Cases {
            switch store.state {
            case .timeline:
              return .timeline(store.scope(state: \.timeline, action: \.timeline)!)
            case let .meeting(v0):
              return .meeting(v0)
            }
          }
        }

        extension Destination: ComposableArchitecture.CaseReducer {
        }
        """#
      }
    }

    func testEnum_Attributes() {
      assertMacro(record: true) {
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
          enum State: CaseReducerState, Equatable {
            typealias Reducer = Destination
            case alert(AlertState<Alert>)
            case dialog(ConfirmationDialogState<Dialog>)
            case meeting(Meeting, syncUp: SyncUp)
          }

          @CasePathable
          enum Action {
            case alert(AlertState<Alert>.Action)
            case dialog(ConfirmationDialogState<Dialog>.Action)
          }

          static var body: some ComposableArchitecture.Reducer<Self.State, Self.Action> {
            CombineReducers {

            }
          }

          enum Cases {
            case alert(AlertState<Alert>)
            case dialog(ConfirmationDialogState<Dialog>)
            case meeting(Meeting, syncUp: SyncUp)
          }

          static func cases(_ store: Store<Self.State, Self.Action>) -> Cases {
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

        extension Destination: ComposableArchitecture.CaseReducer {
        }
        """
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

            struct State: Codable, Equatable, Hashable, ObservableState {
              var _$id: ObservableStateID {
                  ._$inert
              }
              init() {
              }
              mutating func _$willModify() {
              }
            }

            enum Action: Equatable, Hashable {
            }

            let body = EmptyReducer<State, Action>()
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

            public struct State: Codable, Equatable, Hashable, ObservableState {

              public var _$id: ObservableStateID {
                  ._$inert
              }

              public init() {
              }

              public mutating func _$willModify() {
              }
            }

            public enum Action: Equatable, Hashable {
            }

            public let body = EmptyReducer<State, Action>()
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

          let body = EmptyReducer<State, Action>()
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
          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          var body: some Reducer<Int, Bool> { EmptyReducer() }
        }

        extension Feature: ComposableArchitecture.Reducer {
        }
        """
      }
    }
  }
#endif
