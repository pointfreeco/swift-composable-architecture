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
        var body: some ReducerOf<Self> {
          EmptyReducer()
        }
      }
      """
    }
  }
}
