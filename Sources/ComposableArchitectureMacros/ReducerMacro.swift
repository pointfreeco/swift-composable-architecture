import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public enum ReducerMacro {
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
        where: {
          ["Reducer"].withQualified.contains($0.type.trimmedDescription)
        }
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
    if let enumDecl = member.as(EnumDeclSyntax.self) {
      var attributes: [String] = []
      switch enumDecl.name.text {
      case "State":
        attributes = ["CasePathable", "dynamicMemberLookup"]
      case "Action":
        attributes = ["CasePathable"]
      default:
        break
      }
      if let inheritanceClause = enumDecl.inheritanceClause,
        inheritanceClause.inheritedTypes.contains(
          where: {
            ["CasePathable"].withCasePathsQualified.contains($0.type.trimmedDescription)
          }
        )
      {
        attributes.removeAll(where: { $0 == "CasePathable" })
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
    } else if let property = member.as(VariableDeclSyntax.self),
      property.bindingSpecifier.text == "var",
      property.bindings.count == 1,
      let binding = property.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      identifier.text == "body",
      case .getter = binding.accessorBlock?.accessors
    {
      if let reduce = declaration.memberBlock.members.first(where: {
        guard
          let method = $0.decl.as(FunctionDeclSyntax.self),
          method.name.text == "reduce",
          method.signature.parameterClause.parameters.count == 2,
          let state = method.signature.parameterClause.parameters.first,
          state.firstName.text == "into",
          state.type.as(AttributedTypeSyntax.self)?.specifier?.text == "inout",
          method.signature.parameterClause.parameters.last?.firstName.text == "action",
          method.signature.effectSpecifiers == nil,
          method.signature.returnClause?.type.as(IdentifierTypeSyntax.self) != nil
        else {
          return false
        }
        return true
      }) {
        let reduce = reduce.decl.cast(FunctionDeclSyntax.self)
        let visitor = ReduceVisitor(viewMode: .all)
        visitor.walk(declaration)
        context.diagnose(
          Diagnostic(
            node: reduce.name,
            message: MacroExpansionErrorMessage(
              """
              A 'reduce' method should not be defined in a reducer with a 'body'; it takes \
              precedence and 'body' will never be invoked
              """
            ),
            notes: [
              Note(
                node: Syntax(identifier),
                message: MacroExpansionNoteMessage("'body' defined here")
              )
            ]
          )
        )
      }
      for attribute in property.attributes {
        guard
          case let .attribute(attribute) = attribute,
          let attributeName = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
        else { continue }
        guard
          !attributeName.starts(with: "ReducerBuilder"),
          !attributeName.starts(with: "ComposableArchitecture.ReducerBuilder")
        else { return [] }
      }
      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier("ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>")
          )
        )
      ]
    } else {
      return []
    }
  }
}

extension ReducerMacro: MemberMacro {
  public static func expansion<D: DeclGroupSyntax, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    providingMembersOf declaration: D,
    in context: C
  ) throws -> [DeclSyntax] {
    let access = declaration.modifiers.first { $0.name.tokenKind == .keyword(.public) }
    if let enumDecl = declaration.as(EnumDeclSyntax.self) {

      let enumCaseElements = enumDecl.memberBlock
        .members
        .flatMap { member in
          (member.decl.as(EnumCaseDeclSyntax.self)?.elements ?? []).map {
            ReducerCase(
              element: $0,
              isIgnored: (member.decl.as(EnumCaseDeclSyntax.self)?.attributes ?? []).contains(where: {
                if case let .attribute(attribute) = $0 {
                  return attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "ReducerCaseIgnored"
                } else {
                  return false
                }
              })
            )
          }
        }

      var stateCaseDecls: [String] = []
      var actionCaseDecls: [String] = []
      var initialValue: String?
      var reducerScopes: [String] = []
      var storeCases: [String] = []
      var storeScopes: [String] = []

      for (offset, enumCaseElement) in enumCaseElements.enumerated() {
        let element = enumCaseElement.element
        let name = element.name.text
        if enumCaseElement.isIgnored {
          stateCaseDecls.append("case \(element.trimmedDescription)")
          storeCases.append("case \(element.trimmedDescription)")
          storeScopes.append(
            """
            case .\(name)(let x, let y):
            return .\(name)(x, y)
            """
          )
        } else if let parameterClause = element.parameterClause,
          parameterClause.parameters.count == 1,
          let parameter = parameterClause.parameters.first,
          let type = parameter.type.as(IdentifierTypeSyntax.self)
        {
          stateCaseDecls.append("case \(name)(\(type.trimmed).State)")
          actionCaseDecls.append("case \(name)(\(type.trimmed).Action)")
          if offset == 0 {
            initialValue = ".\(name)(\(type.name.text)())"
          }
          reducerScopes.append(
            """
            ComposableArchitecture.Scope(\
            state: \\Self.State.Cases.\(name), action: \\Self.Action.Cases.\(name)\
            ) {
            \(type.name)()
            }
            """
          )
          storeCases.append("case \(name)(ComposableArchitecture.StoreOf<\(type.trimmed)>)")
          storeScopes.append(
            """
            case .\(name):
            return .\(name)(store.scope(state: \\.\(name), action: \\.\(name))!)
            """
          )
        }
        // TODO: else diagnose?
      }
      return [
        """
        @CasePathable
        @dynamicMemberLookup
        @ObservableState
        \(access)enum State: Equatable {
        \(raw: stateCaseDecls.map(\.description).joined(separator: "\n"))
        }
        """,
        """
        @CasePathable
        \(access)enum Action {
        \(raw: actionCaseDecls.map(\.description).joined(separator: "\n"))
        }
        """,
        initialValue.map {
          """
          \(access)init() {
          self = \(raw: $0)
          }
          """
        },
        """
        \(access)var body: some ComposableArchitecture.Reducer<Self.State, Self.Action> {
        CombineReducers {
        \(raw: reducerScopes.joined(separator: "\n"))
        }
        }
        """,
        """
        \(access)enum DestinationStore {
        \(raw: storeCases.joined(separator: "\n"))
        }
        """,
        """
        \(access)static func destination(\
        _ store: Store<Self.State, Self.Action>\
        ) -> DestinationStore {
        switch store.state {
        \(raw: storeScopes.joined(separator: "\n"))
        }
        }
        """
      ].compactMap { $0 }
    } else {
      let typeNames = declaration.memberBlock.members.compactMap {
        $0.as(MemberBlockItemSyntax.self)?.decl.as(StructDeclSyntax.self)?.name.text
        ?? $0.as(MemberBlockItemSyntax.self)?.decl.as(TypeAliasDeclSyntax.self)?.name.text
        ?? $0.as(MemberBlockItemSyntax.self)?.decl.as(EnumDeclSyntax.self)?.name.text
      }
      let hasState = typeNames.contains("State")
      let hasAction = typeNames.contains("Action")
      let bindings = declaration.memberBlock.members.flatMap {
        $0.as(MemberBlockItemSyntax.self)?.decl.as(VariableDeclSyntax.self)?.bindings ?? []
      }
      let hasExplicitReducerBody = bindings.contains {
        $0.typeAnnotation?.type.as(SomeOrAnyTypeSyntax.self)?.constraint
          .as(IdentifierTypeSyntax.self)?.name.text == "Reducer"
      }
      let hasBody = bindings.contains {
        $0.as(PatternBindingSyntax.self)?.pattern
          .as(IdentifierPatternSyntax.self)?.identifier.text == "body"
      }
      var decls: [DeclSyntax] = []
      if !hasState && !hasExplicitReducerBody {
        decls.append("""
          \(access)struct State: Codable, Equatable, Hashable {
            \(access)init() {}
          }
          """)
      }
      if !hasAction && !hasExplicitReducerBody {
        decls.append("""
          \(access)enum Action: Equatable, Hashable {
          }
          """)
      }
      if !hasBody {
        decls.append("\(access)let body = EmptyReducer<State, Action>()")
      }
      return decls
    }
  }
}

private struct ReducerCase {
  let element: EnumCaseElementSyntax
  let isIgnored: Bool
}

extension Array where Element == String {
  var withCasePathsQualified: Self {
    self.flatMap { [$0, "CasePaths.\($0)"] }
  }

  var withQualified: Self {
    self.flatMap { [$0, "ComposableArchitecture.\($0)"] }
  }
}

struct MacroExpansionNoteMessage: NoteMessage {
  var message: String

  init(_ message: String) {
    self.message = message
  }

  var fixItID: MessageID {
    MessageID(domain: diagnosticDomain, id: "\(Self.self)")
  }
}

private let diagnosticDomain: String = "ComposableArchitectureMacros"

private final class ReduceVisitor: SyntaxVisitor {
  var changes: [FixIt.Change] = []

  override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
    guard node.baseName.text == "reduce" else { return super.visit(node) }
    guard
      node.argumentNames == nil
        || node.argumentNames?.arguments.map(\.name.text) == ["into", "action"]
    else { return super.visit(node) }
    if let base = node.parent?.as(MemberAccessExprSyntax.self)?.base,
      base.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind != .keyword(Keyword.`self`)
    {
      return super.visit(node)
    }
    self.changes.append(
      .replace(
        oldNode: Syntax(node),
        newNode: Syntax(node.with(\.baseName, "update"))
      )
    )
    return .visitChildren
  }
}

enum ReducerCaseIgnoredMacro: PeerMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}
