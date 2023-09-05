import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ObservationStateIgnoredMacro.self,
    ObservationStateTrackedMacro.self,
    ObservableStateMacro.self,
    WithViewStoreMacro.self,
  ]
}
