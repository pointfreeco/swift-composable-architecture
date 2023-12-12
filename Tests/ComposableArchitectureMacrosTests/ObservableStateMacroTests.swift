#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  final class ObservableStateMacroTests: MacroBaseTestCase {
    override func invokeTest() {
      withMacroTesting(
         //isRecording: true
      ) {
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
              if _$isIdentityEqual(newValue, _count) {
                _count = newValue
              } else {
                withMutation(keyPath: \.count) {
                  _count = newValue
                }
              }
            }
            _modify {
              func _$forceSet<Member>(
                of subject: inout Self,
                keyPath: WritableKeyPath<Self, Member>,
                member: any ObservableState
              ) {
                subject[keyPath: keyPath] = member as! Member
              }
              func _$asObservableState<T>(_ subject: T) -> (any ObservableState)? {
                subject as? any ObservableState
              }
              func _$forceAsObservableState<T>(_ subject: T) -> any ObservableState {
                subject as! any ObservableState
              }

              guard
                var oldValue = _$asObservableState(_count)
              else {
                _$observationRegistrar.willSet(self, keyPath: \.count)
                defer {
                  _$observationRegistrar.didSet(self, keyPath: \.count)
                }
                yield &_count
                return
              }

              oldValue._$id._flag = true
              _$forceSet(of: &self, keyPath: \._count, member: oldValue)
              yield &_count
              var newValue = _$forceAsObservableState(_count)
              guard !_$isIdentityEqual(oldValue, newValue)
              else {
                newValue._$id._flag = false
                _$forceSet(of: &self, keyPath: \._count, member: newValue)
                return
              }

              _$forceSet(of: &self, keyPath: \._count, member: oldValue)
              withMutation(keyPath: \.count) {
                _$forceSet(of: &self, keyPath: \._count, member: newValue)
              }
            }
          }

          var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

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
              if _$isIdentityEqual(newValue, _count) {
                _count = newValue
              } else {
                withMutation(keyPath: \.count) {
                  _count = newValue
                }
              }
            }
            _modify {
              func _$forceSet<Member>(
                of subject: inout Self,
                keyPath: WritableKeyPath<Self, Member>,
                member: any ObservableState
              ) {
                subject[keyPath: keyPath] = member as! Member
              }
              func _$asObservableState<T>(_ subject: T) -> (any ObservableState)? {
                subject as? any ObservableState
              }
              func _$forceAsObservableState<T>(_ subject: T) -> any ObservableState {
                subject as! any ObservableState
              }

              guard
                var oldValue = _$asObservableState(_count)
              else {
                _$observationRegistrar.willSet(self, keyPath: \.count)
                defer {
                  _$observationRegistrar.didSet(self, keyPath: \.count)
                }
                yield &_count
                return
              }

              oldValue._$id._flag = true
              _$forceSet(of: &self, keyPath: \._count, member: oldValue)
              yield &_count
              var newValue = _$forceAsObservableState(_count)
              guard !_$isIdentityEqual(oldValue, newValue)
              else {
                newValue._$id._flag = false
                _$forceSet(of: &self, keyPath: \._count, member: newValue)
                return
              }

              _$forceSet(of: &self, keyPath: \._count, member: oldValue)
              withMutation(keyPath: \.count) {
                _$forceSet(of: &self, keyPath: \._count, member: newValue)
              }
            }
          }

          var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

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

          var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

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
            get {
              switch self {
              case let .feature1(state):
                return ._$id(for: state)._$tag(0)
              case let .feature2(state):
                return ._$id(for: state)._$tag(1)
              }
            }
            set {
             switch self {
             case var .feature1(state):
             state._$id = newValue
             self = .feature1(state)
             case var .feature2(state):
                state._$id = newValue
                self = .feature2(state)
             }
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
            get {
              switch self {
              case let .feature1(state):
                return ._$id(for: state)._$tag(0)
              case let .feature2(state):
                return ._$id(for: state)._$tag(1)
              }
            }
            set {
             switch self {
             case var .feature1(state):
             state._$id = newValue
             self = .feature1(state)
             case var .feature2(state):
                state._$id = newValue
                self = .feature2(state)
             }
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
            get {
              switch self {
              case .foo:
                return ._$inert._$tag(0)
              }
            }
            set {
             switch self {
             case .foo:
            break
             }
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
