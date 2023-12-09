#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  final class PresentsMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        //isRecording: true,
        macros: [PresentsMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testBasics() {
      assertMacro {
        """
        struct State {
          @Presents var destination: Destination.State?
        }
        """
      } expansion: {
        #"""
        struct State {
          var destination: Destination.State? {
            @storageRestrictions(initializes: _destination)
            init(initialValue) {
              _destination = PresentationState(wrappedValue: initialValue)
            }
            get {
              access(keyPath: \.destination)
              return _destination.wrappedValue
            }
            set {
              if _$isIdentityEqual(newValue, _destination.wrappedValue) {
                _destination.wrappedValue = newValue
              } else {
                withMutation(keyPath: \.destination) {
                  _destination.wrappedValue = newValue
                }
              }
            }
          }

          var $destination: ComposableArchitecture.PresentationState<Destination.State> {
            get {
              access(keyPath: \.destination)
              return _destination.projectedValue
            }
            set {
              if _$isIdentityEqual(newValue, _destination.projectedValue) {
                _destination.projectedValue = newValue
              } else {
                withMutation(keyPath: \.destination) {
                  _destination.projectedValue = newValue
                }
              }
            }
          }

          @ObservationStateIgnored private var _destination = ComposableArchitecture.PresentationState<Destination.State>(wrappedValue: nil)
        }
        """#
      }
    }

    func testPublicAccess() {
      assertMacro {
        """
        public struct State {
          @Presents public var destination: Destination.State?
        }
        """
      } expansion: {
        #"""
        public struct State {
          public var destination: Destination.State? {
            @storageRestrictions(initializes: _destination)
            init(initialValue) {
              _destination = PresentationState(wrappedValue: initialValue)
            }
            get {
              access(keyPath: \.destination)
              return _destination.wrappedValue
            }
            set {
              if _$isIdentityEqual(newValue, _destination.wrappedValue) {
                _destination.wrappedValue = newValue
              } else {
                withMutation(keyPath: \.destination) {
                  _destination.wrappedValue = newValue
                }
              }
            }
          }

          public var $destination: ComposableArchitecture.PresentationState<Destination.State> {
            get {
              access(keyPath: \.destination)
              return _destination.projectedValue
            }
            set {
              if _$isIdentityEqual(newValue, _destination.projectedValue) {
                _destination.projectedValue = newValue
              } else {
                withMutation(keyPath: \.destination) {
                  _destination.projectedValue = newValue
                }
              }
            }
          }

          @ObservationStateIgnored private var _destination = ComposableArchitecture.PresentationState<Destination.State>(wrappedValue: nil)
        }
        """#
      }
    }

    func testObservableStateDiagnostic() {
      assertMacro([
        ObservableStateMacro.self,
        ObservationStateIgnoredMacro.self,
        ObservationStateTrackedMacro.self,
        PresentsMacro.self,
      ]) {
        """
        @ObservableState
        struct State: Equatable {
          @PresentationState var destination: Destination.State?
        }
        """
      } diagnostics: {
        """
        @ObservableState
        struct State: Equatable {
          @PresentationState var destination: Destination.State?
          ┬─────────────────
          ╰─ 🛑 '@PresentationState' property wrapper cannot be used directly in '@ObservableState'
             ✏️ Use '@Presents' instead
        }
        """
      } fixes: {
        """
        @ObservableState
        struct State: Equatable {
          @Presents
        }
        """
      } expansion: {
        """
        struct State: Equatable {

          public var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

          internal nonisolated func access<Member>(
            keyPath: KeyPath<State, Member>
          ) {
            _$observationRegistrar.access(self, keyPath: keyPath)
          }

          internal nonisolated func withMutation<Member, MutationResult>(
            keyPath: KeyPath<State, Member>,
            _ mutation: () throws -> MutationResult
          ) rethrows -> MutationResult {
            try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
          }

          var _$id: ComposableArchitecture.ObservableStateID {
            get {
              self._$observationRegistrar.id
            }
            set {
              self._$observationRegistrar.id = newValue
            }
          }
        }
        """
      }
    }
  }
#endif
