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
          EmptyReducer()
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
             ╰─ ⚠️ A 'reduce' method should not be defined in a reducer with a 'body'; it takes precedence and 'body' will never be invoked
          .none
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
        func reduce(into state: inout State, action: Action) -> EffectOf<Self> {
          .none
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
}
