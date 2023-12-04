@preconcurrency import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ViewActionMacro: MemberMacro {
  public static func expansion<Declaration, Context>(
    of node: SwiftSyntax.AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context
  ) throws -> [SwiftSyntax.DeclSyntax]
  where Declaration: SwiftSyntax.DeclGroupSyntax, Context: SwiftSyntaxMacros.MacroExpansionContext {
    guard declaration.hasStoreVariable
    else {
      // TODO: Fix it to add `let store: StoreOf<<#Feature#>>`?
      context.diagnose(
        Diagnostic(
          node: declaration,
          message: MacroExpansionErrorMessage(
            """
            @ViewAction macro requires \
            \(declaration.identifierDescription.map { "'\($0)' " } ?? "") to have a 'store' \
            property of type 'Store'.
            """
          )
        )
      )
      return []
    }

    declaration.diagnoseDirectStoreDotSend(
      declaration: declaration,
      context: context
    )

    guard
      case let .argumentList(arguments) = node.arguments,
      arguments.count == 1
    else { return [] }
    guard
      let memberAccessExpr = arguments.first?.expression.as(MemberAccessExprSyntax.self)
    else { return [] }
    let rawType = String("\(memberAccessExpr)".dropLast(5))

    return [
      """
      fileprivate func send(_ action: \(raw: rawType).Action.View) {
        self.store.send(.view(action))
      }
      fileprivate func send(_ action: \(raw: rawType).Action.View, animation: Animation?) {
        self.store.send(.view(action), animation: animation)
      }
      """
    ]
  }
}

struct SimpleDiagnosticMessage: DiagnosticMessage, Error {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}

extension SimpleDiagnosticMessage: FixItMessage {
  var fixItID: MessageID { diagnosticID }
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
