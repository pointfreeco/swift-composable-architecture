import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class ObservableStateMacroTests: MacroBaseTestCase {
  func testBasics() {
    assertMacro {
      """
      @ObservableState
      struct State {
        var count = 0
      }
      """
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
            withMutation(keyPath: \.count ) {
              _count  = newValue
            }
          }
        }

        private let _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()
                                                                                               ╰─ 🛑 expected '{}' in variable
                                                                                                  ✏️ insert '{}'

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

  func testAccessControl() {
    assertMacro {
      """
      @ObservableState
      public struct State {
        var count = 0
      }
      """
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
            withMutation(keyPath: \.count ) {
              _count  = newValue
            }
          }
        }

        private let _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()
                                                                                               ╰─ 🛑 expected '{}' in variable
                                                                                                  ✏️ insert '{}'

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

}
