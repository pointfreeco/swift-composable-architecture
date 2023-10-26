import ComposableArchitectureMacros
import MacroTesting
import XCTest

final class ReduceMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      isRecording: true,
      macros: [ReduceMacro.self]
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
        #Reduce<State, Action> { state, action in
          switch action {
          }
        }
      }
      """
    } expansion: {
      """
      @Reducer
      struct Feature {
        struct State {
        }
        enum Action {
        }
        var body: some Reducer<Self.State, Self.Action> {
          Reduce
            { state, action in
              switch action {
              }
            }
        }
      }
      """
    }
  }

  func testBuilder() {
    assertMacro {
      """
      @Reducer
      struct Feature {
        struct State {
        }
        enum Action {
        }
        #Reduce<State, Action> {
          BindingReducer()
          Reduce { state, action in
            switch action {
            }
          }
        }
      }
      """
    } expansion: {
      """
      @Reducer
      struct Feature {
        struct State {
        }
        enum Action {
        }
        var body: some Reducer<Self.State, Self.Action>
          {
            BindingReducer()
            Reduce { state, action in
              switch action {
              }
            }
          }
      }
      """
    }
  }

  func testBuilder_captureList() {
    assertMacro {
      """
      @Reducer
      struct Feature {
        struct State {
        }
        enum Action {
        }
        #Reduce<State, Action> { [self] in
          BindingReducer()
          Reduce { state, action in
            switch action {
            }
          }
        }
      }
      """
    } expansion: {
      """
      @Reducer
      struct Feature {
        struct State {
        }
        enum Action {
        }
        var body: some Reducer<Self.State, Self.Action>
          {
          [self] in
            BindingReducer()
            Reduce { state, action in
              switch action {
              }
            }
          }
      }
      """
    }
  }
}
