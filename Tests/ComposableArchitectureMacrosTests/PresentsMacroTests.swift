#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  final class PresentsMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        // isRecording: true,
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
              _$observationRegistrar.access(self, keyPath: \.destination)
              return _destination.wrappedValue
            }
            set {
              _$observationRegistrar.mutate(self, keyPath: \.destination, &_destination.wrappedValue, newValue, _$isIdentityEqual)
            }
          }

          var $destination: ComposableArchitecture.PresentationState<Destination.State> {
            get {
              _$observationRegistrar.access(self, keyPath: \.destination)
              return _destination.projectedValue
            }
            set {
              _$observationRegistrar.mutate(self, keyPath: \.destination, &_destination.projectedValue, newValue, _$isIdentityEqual)
            }
          }

          @ObservationStateIgnored private var _destination = ComposableArchitecture.PresentationState<Destination.State>(wrappedValue: nil)
        }
        """#
      }
    }

    func testAccessControl() {
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
              _$observationRegistrar.access(self, keyPath: \.destination)
              return _destination.wrappedValue
            }
            set {
              _$observationRegistrar.mutate(self, keyPath: \.destination, &_destination.wrappedValue, newValue, _$isIdentityEqual)
            }
          }

          public var $destination: ComposableArchitecture.PresentationState<Destination.State> {
            get {
              _$observationRegistrar.access(self, keyPath: \.destination)
              return _destination.projectedValue
            }
            set {
              _$observationRegistrar.mutate(self, keyPath: \.destination, &_destination.projectedValue, newValue, _$isIdentityEqual)
            }
          }

          @ObservationStateIgnored private var _destination = ComposableArchitecture.PresentationState<Destination.State>(wrappedValue: nil)
        }
        """#
      }
      assertMacro {
        """
        package struct State {
          @Presents package var destination: Destination.State?
        }
        """
      } expansion: {
        #"""
        package struct State {
          package var destination: Destination.State? {
            @storageRestrictions(initializes: _destination)
            init(initialValue) {
              _destination = PresentationState(wrappedValue: initialValue)
            }
            get {
              _$observationRegistrar.access(self, keyPath: \.destination)
              return _destination.wrappedValue
            }
            set {
              _$observationRegistrar.mutate(self, keyPath: \.destination, &_destination.wrappedValue, newValue, _$isIdentityEqual)
            }
          }

          package var $destination: ComposableArchitecture.PresentationState<Destination.State> {
            get {
              _$observationRegistrar.access(self, keyPath: \.destination)
              return _destination.projectedValue
            }
            set {
              _$observationRegistrar.mutate(self, keyPath: \.destination, &_destination.projectedValue, newValue, _$isIdentityEqual)
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
          ╰─ 🛑 '@PresentationState' cannot be used in '@ObservableState'
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

          var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

          public var _$id: ComposableArchitecture.ObservableStateID {
            _$observationRegistrar.id
          }

          public mutating func _$willModify() {
            _$observationRegistrar._$willModify()
          }
        }
        """
      }
    }
  }
#endif
