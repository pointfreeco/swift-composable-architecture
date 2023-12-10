#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  final class ObservableStateMacroTests: MacroBaseTestCase {
    override func invokeTest() {
      withMacroTesting {
        super.invokeTest()
      }
    }

    func testAvailability() {
      assertMacro {
        """
        @ObservableState
        @available(iOS 18, *)
        struct State {
          var count = 0
        }
        """
      } expansion: {
        #"""
        @available(iOS 18, *)
        struct State {
          var count = 0 {
            @storageRestrictions(initializes: _count)
            init(initialValue) {
              _count = initialValue
            }
            get {
              access(keyPath: \.count)
              return _count
            }
            set {
              if _$isIdentityEqual(newValue, _count) == true {
                _count = newValue
              } else {
                withMutation(keyPath: \.count) {
                  _count = newValue
                }
              }
            }
          }

          private let _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

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
            self._$observationRegistrar.id
          }
        }
        """#
      }
    }

    func testObservableState() throws {
      assertMacro {
        #"""
        @ObservableState
        struct State {
          var count = 0
        }
        """#
      } expansion: {
        #"""
        struct State {
          var count = 0 {
            @storageRestrictions(initializes: _count)
            init(initialValue) {
              _count = initialValue
            }
            get {
              access(keyPath: \.count)
              return _count
            }
            set {
              if _$isIdentityEqual(newValue, _count) == true {
                _count = newValue
              } else {
                withMutation(keyPath: \.count) {
                  _count = newValue
                }
              }
            }
          }

          private let _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

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
            self._$observationRegistrar.id
          }
        }
        """#
      }
    }

    func testObservableStateIgnored() throws {
      assertMacro {
        #"""
        @ObservableState
        struct State {
          @ObservationStateIgnored
          var count = 0
        }
        """#
      } expansion: {
        """
        struct State {
          var count = 0

          private let _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

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
            self._$observationRegistrar.id
          }
        }
        """
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
      } expansion: {
        """
        enum Path {
          case feature1(Feature1.State)
          case feature2(Feature2.State)

          var _$id: ComposableArchitecture.ObservableStateID {
            switch self {
            case let .feature1(state):
              return ._$id(for: state)._$tag(0)
            case let .feature2(state):
              return ._$id(for: state)._$tag(1)
            }
          }
        }
        """
      }
    }

    func testObservableState_Enum_AccessControl() {
      assertMacro {
        """
        @ObservableState
        public enum Path {
          case feature1(Feature1.State)
          case feature2(Feature2.State)
        }
        """
      } expansion: {
        """
        public enum Path {
          case feature1(Feature1.State)
          case feature2(Feature2.State)

          public var _$id: ComposableArchitecture.ObservableStateID {
            switch self {
            case let .feature1(state):
              return ._$id(for: state)._$tag(0)
            case let .feature2(state):
              return ._$id(for: state)._$tag(1)
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
      } expansion: {
        """
        public enum Path {
          case foo(Int, String)

          public var _$id: ComposableArchitecture.ObservableStateID {
            switch self {
            case .foo:
              return ._$inert._$tag(0)
            }
          }
        }
        """
      }
    }

    func testObservableState_Class() {
      assertMacro {
        """
        @ObservableState
        public class Model {
        }
        """
      } diagnostics: {
        """
        @ObservableState
        ┬───────────────
        ╰─ 🛑 '@ObservableState' cannot be applied to class type 'Model'
        public class Model {
        }
        """
      }
    }

    func testObservableState_Actor() {
      assertMacro {
        """
        @ObservableState
        public actor Model {
        }
        """
      } diagnostics: {
        """
        @ObservableState
        ┬───────────────
        ╰─ 🛑 '@ObservableState' cannot be applied to actor type 'Model'
        public actor Model {
        }
        """
      }
    }
  }
#endif
