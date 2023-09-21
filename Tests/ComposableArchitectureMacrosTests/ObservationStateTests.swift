import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class ObservableStateMacroTests: MacroBaseTestCase {
  func testObservableState() throws {
    assertMacro {
      #"""
      @ObservableState
      struct State {
        var count = 0
      }
      """#
    } matches: {
      #"""
      struct State {
        var count = 0 {
          @storageRestrictions(initializes: _count )
          init(initialValue) {
            _count  = initialValue
          }
          get {
            access(keyPath: \.count )
            return _count
          }
          set {
            if isIdentityEqual(newValue, _count ) == true {
              _count  = newValue
            } else {
              withMutation(keyPath: \.count ) {
                _count  = newValue
              }
            }
          }
        }

        private let _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

        internal nonisolated func access<Member>(
            keyPath: KeyPath<State , Member>
        ) {
          _$observationRegistrar.access(self, keyPath: keyPath)
        }

        internal nonisolated func withMutation<Member, MutationResult>(
          keyPath: KeyPath<State , Member>,
          _ mutation: () throws -> MutationResult
        ) rethrows -> MutationResult {
          try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
        }

        var _$id: StateID {
          self._$observationRegistrar.id
        }
      }
      """#
    }
  }

  func testObservableState_Enum() {
    assertMacro {
      """
      @ObservableState
      enum Path {
        case feature1(Feature1.State)
        case feature2(Feature2.State)
      }
      """
    } matches: {
      """
      enum Path {
        case feature1(Feature1.State)
        case feature2(Feature2.State)

        var _$id: StateID {
          switch self {
          case let .feature1(state):
            return .stateID(for: state).tagged(0)
          case let .feature2(state):
            return .stateID(for: state).tagged(1)
          }
        }
      }
      """
    }
  }

  func testObservableState_Enum_Accessor() {
    assertMacro {
      """
      @ObservableState
      public enum Path {
        case feature1(Feature1.State)
        case feature2(Feature2.State)
      }
      """
    } matches: {
      """
      public enum Path {
        case feature1(Feature1.State)
        case feature2(Feature2.State)

        public var _$id: StateID {
          switch self {
          case let .feature1(state):
            return .stateID(for: state).tagged(0)
          case let .feature2(state):
            return .stateID(for: state).tagged(1)
          }
        }
      }
      """
    }
  }

  func testObservableState_Enum_MultipleAssociatedValues() {
    assertMacro {
      """
      @ObservableState
      public enum Path {
        case foo(Int, String)
      }
      """
    } matches: {
      """
      public enum Path {
        case foo(Int, String)

        public var _$id: StateID {
          switch self {
          case .foo:
            return .inert.tagged(0)
          }
        }
      }
      """
    }
  }
}
