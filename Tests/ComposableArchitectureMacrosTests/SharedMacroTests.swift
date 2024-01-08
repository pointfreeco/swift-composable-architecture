#if canImport(ComposableArchitectureMacros)
  import ComposableArchitectureMacros
  import MacroTesting
  import SwiftSyntaxMacros
  import SwiftSyntaxMacrosTestSupport
  import XCTest

  final class SharedMacroTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        // isRecording: true,
        macros: [SharedMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testBasics() {
      assertMacro(record: true) {
        """
        struct State {
          @Shared var settings: Settings
        }
        """
      } expansion: {
        """
        struct State {
          var settings: Settings {
            get {
              _settings.value
            }
            set {
              _settings.value = newValue
            }
          }

          @ObservationStateIgnored @Dependencies.Dependency(ComposableArchitecture.Shared<Settings>.self) private var _settings
        }
        """
      }
    }

    func testObservableState() {
      assertMacro([ObservableStateMacro.self, SharedMacro.self], record: true) {
        """
        @ObservableState
        struct State {
          @Shared var settings: Settings
        }
        """
      } expansion: {
        """
        struct State {
          @ObservationStateIgnored 
          var settings: Settings {
            get {
              _settings.value
            }
            set {
              _settings.value = newValue
            }
          }

          @ObservationStateIgnored  @ObservationStateIgnored @Dependencies.Dependency(ComposableArchitecture.Shared<Settings>.self) private var _settings

          @ObservationStateIgnored var _$observationRegistrar = ComposableArchitecture.ObservationStateRegistrar()

          var _$id: ComposableArchitecture.ObservableStateID {
            _$observationRegistrar.id
          }

          mutating func _$willModify() {
            _$observationRegistrar._$willModify()
          }
        }
        """
      }
    }
  }
#endif
