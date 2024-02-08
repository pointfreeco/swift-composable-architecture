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
          leadingTrivia: declarationWithStoreVariable.memberBlock.members.first?.leadingTrivia
            ?? "\n    ",
          decl: VariableDeclSyntax(
            bindingSpecifier: declaration.modifiers.bindingSpecifier(),
            bindings: [
              PatternBindingSyntax(
                pattern: " store" as PatternSyntax,
                typeAnnotation: TypeAnnotationSyntax(
                  type: " StoreOf<\(raw: inputType)>" as TypeSyntax
                )
              )
            ]
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
            '@ViewAction' requires \
            \(declaration.identifierDescription.map { "'\($0)' " } ?? " ")to have a 'store' \
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
      \(declaration.attributes.availability)extension \(type.trimmed): \
      ComposableArchitecture.ViewActionSending {}
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
      if let functionCall = decl.as(FunctionCallExprSyntax.self) {
        if let sendExpression = functionCall.sendExpression {
          var fixIt: FixIt?
          if let outer = functionCall.arguments.first,
            let inner =
              outer
              .as(LabeledExprSyntax.self)?.expression
              .as(FunctionCallExprSyntax.self),
            inner.calledExpression
              .as(MemberAccessExprSyntax.self)?.declName.baseName.text == "view",
            inner.arguments.count == 1
          {
            var newFunctionCall = functionCall
            newFunctionCall.calledExpression = sendExpression
            newFunctionCall.arguments = inner.arguments
            fixIt = .replace(
              message: MacroExpansionFixItMessage("Call 'send' directly with a view action"),
              oldNode: functionCall,
              newNode: newFunctionCall
            )
          }
          context.diagnose(
            Diagnostic(
              node: decl,
              message: MacroExpansionWarningMessage(
                """
                Do not use 'store.send' directly when using '@ViewAction'
                """
              ),
              highlights: [decl],
              fixIts: fixIt.map { [$0] } ?? []
            )
          )
        }
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

extension DeclModifierListSyntax {
  fileprivate func bindingSpecifier() -> TokenSyntax {
    guard
      let modifier = first(where: {
        $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.package)
      })
    else { return "let" }
    return "\(raw: modifier.name.text) let"
  }
}

extension FunctionCallExprSyntax {
  fileprivate var sendExpression: ExprSyntax? {
    guard
      let memberAccess = self.calledExpression.as(MemberAccessExprSyntax.self),
      memberAccess.declName.baseName.text == "send"
    else { return nil }

    if memberAccess.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "store" {
      return ExprSyntax(DeclReferenceExprSyntax(baseName: "send"))
    }

    if let innerMemberAccess = memberAccess.base?.as(MemberAccessExprSyntax.self),
      innerMemberAccess.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self",
      innerMemberAccess.declName.baseName.text == "store"
    {
      return ExprSyntax(
        MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: "self"), name: "send")
      )
    }

    return nil
  }
}
