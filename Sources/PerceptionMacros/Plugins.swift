import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    PerceptibleMacro.self,
    PerceptionTrackedMacro.self,
    PerceptionIgnoredMacro.self,
  ]
}
