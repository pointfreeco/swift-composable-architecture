import ComposableArchitectureMacros
import MacroTesting
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class ObservableStateMacroTests: MacroBaseTestCase {
  func testObservableState_ObservationTrackedWhen() throws {
    assertMacro {
      #"""
      @ObservableState
      struct State {
        var children = IdentifiedArrayOf<ChildFeature.State>()
      }
      """#
    } matches: {
      #"""
      struct State {
        var children = IdentifiedArrayOf<ChildFeature.State>() {
          init(initialValue) initializes(_children ) {
                             ╰─ 🛑 unexpected code 'initializes(_children )' in accessor
            _children  = initialValue
          }
          get {
            access(keyPath: \.children )
            return _children
          }
          set {
            if _identifiedArrayIDsAreNotEqual(_children , newValue) {
              withMutation(keyPath: \.children ) {
                _children  = newValue
              }
            } else {
              _children  = newValue
            }
          }
        }

        @ObservationIgnored private let _$observationRegistrar = Observation.ObservationRegistrar()

        internal nonisolated func access<Member>(
            keyPath: KeyPath<State , Member>
        ) {
          _$observationRegistrar.access(self, keyPath: keyPath)
        }

        internal nonisolated func withMutation<Member, T>(
          keyPath: KeyPath<State , Member>,
          _ mutation: () throws -> T
        ) rethrows -> T {
          try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
        }

        let _$id = StateID()
      }

      extension State: ComposableArchitecture.ObservableState, Observation.Observable {
      }
      """#
    }
  }
}
