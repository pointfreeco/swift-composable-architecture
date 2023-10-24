import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics
import SwiftOperators
import SwiftSyntaxBuilder

public enum ReducerMacro {
}

extension DeclGroupSyntax {
  var inheritanceClause: InheritanceClauseSyntax? {
    if let decl = self.as(StructDeclSyntax.self) {
      return decl.inheritanceClause
    } else if let decl = self.as(ClassDeclSyntax.self) {
      return decl.inheritanceClause
    } else if let decl = self.as(EnumDeclSyntax.self) {
      return decl.inheritanceClause
    } else {
      return nil
    }
  }
}

extension ReducerMacro: ExtensionMacro {
  public static func expansion<D: DeclGroupSyntax, T: TypeSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    attachedTo declaration: D,
    providingExtensionsOf type: T,
    conformingTo protocols: [TypeSyntax],
    in context: C
  ) throws -> [ExtensionDeclSyntax] {
    if let inheritanceClause = declaration.inheritanceClause,
      inheritanceClause.inheritedTypes.contains(
        where: { ["ComposableArchitecture.Reducer", "Reducer"].contains($0.type.trimmedDescription) }
      )
    {
      return []
    }
    let ext: DeclSyntax =
      """
      extension \(type.trimmed): ComposableArchitecture.Reducer {}
      """
    return [ext.cast(ExtensionDeclSyntax.self)]
  }
}

extension ReducerMacro: MemberAttributeMacro {
  public static func expansion<D: DeclGroupSyntax, M: DeclSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    attachedTo declaration: D,
    providingAttributesFor member: M,
    in context: C
  ) throws -> [AttributeSyntax] {
    guard let enumDecl = member.as(EnumDeclSyntax.self) 
    else { return [] }

    var attributes: [String] = []
    switch enumDecl.name.text {
    case "State":
      attributes = ["CasePathable", "dynamicMemberLookup"]
    case "Action":
      attributes = ["CasePathable"]
    default:
      break
    }
    for attribute in enumDecl.attributes {
      guard
        case let .attribute(attribute) = attribute,
        let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
      else { continue }
      attributes.removeAll(where: { $0 == attributeName })
    }
    return attributes.map {
      AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier($0)))
    }
  }
}
