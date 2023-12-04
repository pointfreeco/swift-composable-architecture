import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ViewActionMacro: ExtensionMacro {

  public static func expansion<D: DeclGroupSyntax, T: TypeSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    attachedTo declaration: D,
    providingExtensionsOf type: T,
    conformingTo protocols: [TypeSyntax],
    in context: C
  ) throws -> [ExtensionDeclSyntax] {
    guard
      case let .argumentList(arguments) = node.arguments,
      arguments.count == 1,
      let memberAccessExpr = arguments.first?.expression.as(MemberAccessExprSyntax.self)
    else { return [] }
    let inputType = String("\(memberAccessExpr)".dropLast(5))

    guard declaration.hasStoreVariable
    else {
      var declarationWithStoreVariable = declaration
      declarationWithStoreVariable.memberBlock.members.insert(
        MemberBlockItemSyntax(
          leadingTrivia: .newline,
          decl: VariableDeclSyntax(
            .let,
            name: " store: StoreOf<\(raw: inputType)>"
          ),
          trailingTrivia: .newline
        ),
        at: declarationWithStoreVariable.memberBlock.members.startIndex
      )

      context.diagnose(
        Diagnostic(
          node: declaration,
          message: MacroExpansionErrorMessage(
            """
            @ViewAction macro requires \
            \(declaration.identifierDescription.map { "'\($0)' " } ?? "") to have a 'store' \
            property of type 'Store'.
            """
          ),
          fixIt: .replace(
            message: MacroExpansionFixItMessage("Add 'store'"),
            oldNode: declaration,
            newNode: declarationWithStoreVariable
          )
        )
      )
      return []
    }

    declaration.diagnoseDirectStoreDotSend(
      declaration: declaration,
      context: context
    )

    let ext: DeclSyntax =
      """
      extension \(type.trimmed): ComposableArchitecture.ViewActionable {}
      """
    return [ext.cast(ExtensionDeclSyntax.self)]
  }
}

extension SyntaxProtocol {
  func diagnoseDirectStoreDotSend<D: SyntaxProtocol>(
    declaration: D,
    context: some MacroExpansionContext
  ) {
    for decl in declaration.children(viewMode: .fixedUp) {
      if let memberAccess = decl.as(MemberAccessExprSyntax.self),
        let identifierSyntax = memberAccess.base?.as(DeclReferenceExprSyntax.self),
        identifierSyntax.baseName.text == "store",
        memberAccess.declName.baseName.text == "send"
      {
        context.diagnose(
          Diagnostic(
            node: decl,
            message: MacroExpansionWarningMessage(
              """
              Do not use 'store.send' directly when using @ViewAction. Instead, use 'send'.
              """
            ),
            highlights: [decl],
            fixIt: .replace(
              message: MacroExpansionFixItMessage("Use 'send'"),
              oldNode: decl,
              newNode: DeclReferenceExprSyntax(baseName: "send")
            )
          )
        )
      }
      if let memberAccess = decl.as(MemberAccessExprSyntax.self),
        let selfMemberAccess = memberAccess.base?.as(MemberAccessExprSyntax.self),
        selfMemberAccess.declName.baseName.text == "store",
        memberAccess.declName.baseName.text == "send"
      {
        context.diagnose(
          Diagnostic(
            node: decl,
            message: MacroExpansionWarningMessage(
              """
              Do not use 'self.store.send' directly when using @ViewAction. Instead, use 'self.send'.
              """
            ),
            highlights: [decl],
            fixIt: .replace(
              message: MacroExpansionFixItMessage("Use 'self.send'"),
              oldNode: decl,
              newNode: DeclReferenceExprSyntax(baseName: "self.send")
            )
          )
        )
      }
      decl.diagnoseDirectStoreDotSend(declaration: decl, context: context)
    }
  }
}

extension DeclGroupSyntax {
  fileprivate var hasStoreVariable: Bool {
    self.memberBlock.members.contains(where: { member in
      if let variableDecl = member.decl.as(VariableDeclSyntax.self),
        let firstBinding = variableDecl.bindings.first,
        let identifierPattern = firstBinding.pattern.as(IdentifierPatternSyntax.self),
        identifierPattern.identifier.text == "store"
      {
        return true
      } else {
        return false
      }
    })
  }
}

extension DeclGroupSyntax {
  var identifierDescription: String? {
    switch self {
    case let syntax as ActorDeclSyntax:
      return syntax.name.trimmedDescription
    case let syntax as ClassDeclSyntax:
      return syntax.name.trimmedDescription
    case let syntax as ExtensionDeclSyntax:
      return syntax.extendedType.trimmedDescription
    case let syntax as ProtocolDeclSyntax:
      return syntax.name.trimmedDescription
    case let syntax as StructDeclSyntax:
      return syntax.name.trimmedDescription
    case let syntax as EnumDeclSyntax:
      return syntax.name.trimmedDescription
    default:
      return nil
    }
  }
}
