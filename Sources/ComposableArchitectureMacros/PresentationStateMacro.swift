import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum PresentationStateMacro: AccessorMacro, PeerMacro {
  public static func expansion<D: DeclSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: D,
    in context: C
  ) throws -> [AccessorDeclSyntax] {
    guard
      let property = declaration.as(VariableDeclSyntax.self),
      let binding = property.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed,
      binding.typeAnnotation?.type.is(OptionalTypeSyntax.self) == true
    else {
      return []
    }

    return [
      """
      @storageRestrictions(initializes: $\(identifier))
      init(initialValue) {
      $\(identifier) = PresentationState(wrappedValue: initialValue)
      }
      """,
      """
      get {
      $\(identifier).wrappedValue
      }
      """,
      """
      set {
      $\(identifier).wrappedValue = newValue
      }
      """,
    ]
  }

  public static func expansion<D: DeclSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    providingPeersOf declaration: D,
    in context: C
  ) throws -> [DeclSyntax] {
    guard
      let property = declaration.as(VariableDeclSyntax.self),
      let binding = property.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed,
      let type = binding.typeAnnotation?.type.trimmed.as(OptionalTypeSyntax.self)
    else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: SimpleDiagnosticMessage(
            message: """
              '@PresentationState' must be attached to an optional property
              """,
            diagnosticID: "closure-property",
            severity: .error
          )
        )
      )
      return []
    }

    let access = property.modifiers.first { $0.name.tokenKind == .keyword(.public) }
    return [
      // NB: Can't simply attach '@ObservationStateIgnored' here
      """
      \(access)var $\(identifier) = \
      ComposableArchitecture.PresentationState<\(type.wrappedType)>(
      wrappedValue: nil
      )
      """
    ]
  }
}
