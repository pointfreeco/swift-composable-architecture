import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    FeatureMacro.self,
    ObservableStateMacro.self,
    ObservationStateTrackedMacro.self,
    ObservationStateIgnoredMacro.self,
    //ObservationTrackedWhenMacro.self,
    WithViewStoreMacro.self,
  ]
}
