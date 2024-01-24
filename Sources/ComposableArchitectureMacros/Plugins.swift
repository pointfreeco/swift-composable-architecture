import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ObservableStateMacro.self,
    ObservationStateTrackedMacro.self,
    ObservationStateIgnoredMacro.self,
    PresentsMacro.self,
    ReducerMacro.self,
    ReducerCaseEphemeralMacro.self,
    ReducerCaseIgnoredMacro.self,
    ViewActionMacro.self,
  ]
}
