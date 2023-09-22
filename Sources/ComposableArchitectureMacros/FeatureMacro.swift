import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

private struct Failure: Error {}

public struct FeatureMacro: ExpressionMacro {
  static let moduleName = "ComposableArchitecture"
  static let featureTypeName = "Feature"
  static var qualifiedFeatureTypeName: String { "\(Self.moduleName).\(Self.featureTypeName)" }

  public static func expansion<N: FreestandingMacroExpansionSyntax, C: MacroExpansionContext>(
    of node: N,
    in context: C
  ) throws -> ExprSyntax {
    let keyPathExpr = node.argumentList.last!.expression.cast(KeyPathExprSyntax.self)

    let action = try keyPathExpr.components.reversed().reduce(into: "$0") { action, component in
      if let name = component.component
        .as(KeyPathPropertyComponentSyntax.self)?
        .declName
        .baseName
        .text
      {
        action = ".\(name.hasPrefix("$") ? name.dropFirst() : name[...])(\(action))"
      } else if component.component.is(KeyPathOptionalComponentSyntax.self) {
        action = "$0.presented { \(action) }"
      } else {
        throw Failure()
      }
    }
    
//    return """
//      \(raw: Self.qualifiedFeatureTypeName)(
//        state: \(keyPathExpr),
//        action: { \(raw: action) }
//      )
//      """
    return """
      .init(
        state: \(keyPathExpr),
        action: { \(raw: action) }
      )
      """
  }
}
