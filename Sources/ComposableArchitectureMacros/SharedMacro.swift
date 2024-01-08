import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public enum SharedMacro {
}

extension SharedMacro: AccessorMacro {
  public static func expansion<D: DeclSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: D,
    in context: C
  ) throws -> [AccessorDeclSyntax] {
    guard
      let property = declaration.as(VariableDeclSyntax.self),
      let identifier = property.identifier?.trimmed
    else {
      return []
    }

    let getAccessor: AccessorDeclSyntax =
      """
      get {
      _\(identifier).wrappedValue.value
      }
      """

    let setAccessor: AccessorDeclSyntax =
      """
      set {
      _\(identifier).wrappedValue.value = newValue
      }
      """

    return [getAccessor, setAccessor]
  }
}

extension SharedMacro: PeerMacro {
  public static func expansion<D: DeclSyntaxProtocol, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    providingPeersOf declaration: D,
    in context: C
  ) throws -> [DeclSyntax] {
    guard
      let property = declaration.as(VariableDeclSyntax.self),
      let identifier = property.identifier?.trimmed,
      let type = property.bindings.first?.typeAnnotation?.type
    else {
      return []
    }
    return [
      """
      let _\(identifier) = \
      Dependencies.Dependency(ComposableArchitecture.Shared<\(type)>.self)
      """
//      DeclSyntax(
//        property.privateWrapped(addingAttributes: [
//          ObservableStateMacro.ignoredAttribute,
//          AttributeSyntax(
//            atSign: .atSignToken(),
//            attributeName: IdentifierTypeSyntax(name: .identifier("Dependencies.Dependency")),
//            leftParen: .leftParenToken(),
//            arguments: .argumentList([
//              LabeledExprSyntax(
//                expression: "ComposableArchitecture.Shared<\(type)>.self" as ExprSyntax
//              )
//            ]),
//            rightParen: .rightParenToken(),
//            trailingTrivia: .space
//          )
//        ])
//      )
    ]
  }
}

extension VariableDeclSyntax {
  fileprivate func privateWrapped(
    addingAttributes attributes: [AttributeSyntax]
  ) -> VariableDeclSyntax {
    var oldAttributes = self.attributes
    for index in oldAttributes.indices.reversed() {
      let attribute = oldAttributes[index]
      switch attribute {
      case let .attribute(attribute):
        if attribute.attributeName.tokens(viewMode: .all).map(\.tokenKind) == [
          .identifier("Shared")
        ] {
          oldAttributes.remove(at: index)
        }
      default:
        break
      }
    }
    let newAttributes = oldAttributes + attributes.map { .attribute($0) }
    return VariableDeclSyntax(
      leadingTrivia: leadingTrivia,
      attributes: newAttributes,
      modifiers: modifiers.privatePrefixed("_"),
      bindingSpecifier: TokenSyntax(
        bindingSpecifier.tokenKind, trailingTrivia: .space,
        presence: .present
      ),
      bindings: bindings.privateWrapped,
      trailingTrivia: trailingTrivia
    )
  }
}

extension PatternBindingListSyntax {
  fileprivate var privateWrapped: PatternBindingListSyntax {
    var bindings = self
    for index in bindings.indices {
      let binding = bindings[index]
      if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
        bindings[index] = PatternBindingSyntax(
          leadingTrivia: binding.leadingTrivia,
          pattern: IdentifierPatternSyntax(
            leadingTrivia: identifier.leadingTrivia,
            identifier: identifier.identifier.privatePrefixed("_"),
            trailingTrivia: identifier.trailingTrivia
          ),
          trailingTrivia: binding.trailingTrivia
        )
      }
    }
    return bindings
  }
}
