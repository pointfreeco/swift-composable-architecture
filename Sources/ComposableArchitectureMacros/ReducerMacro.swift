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
    let proto =
      declaration.isEnum
      ? "ComposableArchitecture.CaseReducer, ComposableArchitecture.Reducer"
      : "ComposableArchitecture.Reducer"
    let ext: DeclSyntax =
      """
      \(declaration.attributes.availability)extension \(type.trimmed): \(raw: proto) {}
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
      case .getter = binding.accessorBlock?.accessors,
      let genericArguments = binding.typeAnnotation?
        .type.as(SomeOrAnyTypeSyntax.self)?
        .constraint.as(IdentifierTypeSyntax.self)?
        .genericArgumentClause?
        .arguments
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
      let genericArguments =
        genericArguments.count == 1
        ? "\(genericArguments.description).State, \(genericArguments.description).Action"
        : "\(genericArguments)"
      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier("ComposableArchitecture.ReducerBuilder<\(genericArguments)>")
          )
        )
      ]
    } else if let enumCaseDecl = member.as(EnumCaseDeclSyntax.self),
      enumCaseDecl.elements.count == 1,
      let element = enumCaseDecl.elements.first
    {
      if let parameterClause = element.parameterClause,
        parameterClause.parameters.count == 1,
        let parameter = parameterClause.parameters.first
      {
        if parameter.type.as(IdentifierTypeSyntax.self)?.isEphemeral == true {
          return [
            AttributeSyntax(
              attributeName: IdentifierTypeSyntax(
                name: .identifier("ReducerCaseEphemeral")
              )
            )
          ]
        } else {
          return []
        }
      } else {
        return [
          AttributeSyntax(
            attributeName: IdentifierTypeSyntax(
              name: .identifier("ReducerCaseIgnored")
            )
          )
        ]
      }
    } else {
      return []
    }
  }
}

extension IdentifierTypeSyntax {
  fileprivate var isEphemeral: Bool {
    self.name.text == "AlertState" || self.name.text == "ConfirmationDialogState"
  }
}

extension ReducerMacro: MemberMacro {
  public static func expansion<D: DeclGroupSyntax, C: MacroExpansionContext>(
    of node: AttributeSyntax,
    providingMembersOf declaration: D,
    in context: C
  ) throws -> [DeclSyntax] {
    let access = declaration.modifiers.first { $0.name.tokenKind == .keyword(.public) }
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
    let hasReduceMethod = declaration.memberBlock.members.contains {
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
    }
    let hasExplicitReducerBody =
      bindings.contains {
        guard $0.initializer == nil
        else { return true }
        guard
          let name = $0.typeAnnotation?.type.as(SomeOrAnyTypeSyntax.self)?.constraint
            .as(IdentifierTypeSyntax.self)?.name.text
        else {
          return false
        }
        return ["Reducer", "ReducerOf"].withQualified.contains(name)
      } || hasReduceMethod
    let hasBody =
      bindings.contains {
        $0.as(PatternBindingSyntax.self)?.pattern
          .as(IdentifierPatternSyntax.self)?.identifier.text == "body"
      } || hasReduceMethod
    var decls: [DeclSyntax] = []
    if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      let enumCaseElements = enumDecl.memberBlock
        .members
        .flatMap { member -> [ReducerCase] in
          guard let decl = member.decl.as(EnumCaseDeclSyntax.self) else { return [] }
          return decl.elements.map {
            ReducerCase(element: $0, attribute: decl.attribute)
          }
        }

      var stateCaseDecls: [String] = []
      var actionCaseDecls: [String] = []
      var reducerScopes: [String] = []
      var storeCases: [String] = []
      var storeScopes: [String] = []
      var reducerTypeScopes: [String] = []

      for enumCaseElement in enumCaseElements {
        let element = enumCaseElement.element
        let name = element.name.text

        if enumCaseElement.attribute != .ignored,
          let parameterClause = element.parameterClause,
          parameterClause.parameters.count == 1,
          let parameter = parameterClause.parameters.first,
          parameter.type.is(IdentifierTypeSyntax.self) || parameter.type.is(MemberTypeSyntax.self)
        {
          let type = parameter.type
          let stateCase =
            enumCaseElement.attribute == .ephemeral
            ? element
            : element.suffixed("State")
          stateCaseDecls.append("case \(stateCase.trimmedDescription)")
          actionCaseDecls.append("case \(element.suffixed("Action").trimmedDescription)")
          if enumCaseElement.attribute == nil {
            reducerScopes.append(
              """
              ComposableArchitecture.Scope(\
              state: \\Self.State.Cases.\(name), action: \\Self.Action.Cases.\(name)\
              ) {
              \(type.trimmed)()
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
            reducerTypeScopes.append(
              """
              ComposableArchitecture.Scope<Self.State, Self.Action, \(type.trimmed)>
              """
            )
          }
        } else {
          stateCaseDecls.append("case \(element.trimmedDescription)")
        }
        if enumCaseElement.attribute != nil {
          storeCases.append("case \(element.trimmedDescription)")
          if let parameters = element.parameterClause?.parameters {
            let bindingNames = (0..<parameters.count).map { "v\($0)" }.joined(separator: ", ")
            let returnNames = parameters.enumerated()
              .map { "\($1.firstName.map { "\($0.text): " } ?? "")v\($0)" }
              .joined(separator: ", ")
            storeScopes.append(
              """
              case let .\(name)(\(bindingNames)):
              return .\(name)(\(returnNames))
              """
            )
          } else {
            storeScopes.append(
              """
              case .\(name):
              return .\(name)
              """
            )
          }
        }
      }
      if !hasState {
        var conformances: [String] = []
        if case let .argumentList(arguments) = node.arguments,
          let startIndex = arguments.firstIndex(where: { $0.label?.text == "state" })
        {
          let endIndex =
            arguments.firstIndex(where: { $0.label?.text == "action" })
            ?? arguments.endIndex
          conformances.append(
            contentsOf: arguments[startIndex..<endIndex].compactMap {
              $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text.capitalized
            }
          )
        }
        decls.append(
          """
          @CasePathable
          @dynamicMemberLookup
          @ObservableState
          \(access)enum State: ComposableArchitecture.CaseReducerState\
          \(raw: conformances.isEmpty ? "" : ", \(conformances.joined(separator: ", "))") {
          \(access)typealias StateReducer = \(enumDecl.name.trimmed)
          \(raw: stateCaseDecls.map(\.description).joined(separator: "\n"))
          }
          """
        )
      }
      if !hasAction {
        var conformances: [String] = []
        if case let .argumentList(arguments) = node.arguments,
          let startIndex = arguments.firstIndex(where: { $0.label?.text == "action" })
        {
          conformances.append(
            contentsOf: arguments[startIndex..<arguments.endIndex].compactMap {
              $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text.capitalized
            }
          )
        }
        decls.append(
          """
          @CasePathable
          \(access)enum Action\
          \(raw: conformances.isEmpty ? "" : ": \(conformances.joined(separator: ", "))") {
          \(raw: actionCaseDecls.map(\.description).joined(separator: "\n"))
          }
          """
        )
      }
      if !hasBody {
        var staticVarBody = ""
        if reducerTypeScopes.isEmpty {
          staticVarBody = "ComposableArchitecture.EmptyReducer<Self.State, Self.Action>"
        } else if reducerTypeScopes.count == 1 {
          staticVarBody = reducerTypeScopes[0]
        } else {
          for _ in 1...(reducerTypeScopes.count - 1) {
            staticVarBody.append(
              "ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>._Sequence<"
            )
          }
          staticVarBody.append(reducerTypeScopes[0])
          staticVarBody.append(", ")
          for type in reducerTypeScopes.dropFirst() {
            staticVarBody.append(type)
            staticVarBody.append(">, ")
          }
          staticVarBody.removeLast(2)
        }

        decls.append(
          """
          @ComposableArchitecture.ReducerBuilder<Self.State, Self.Action>
          \(access)static var body: \(raw: staticVarBody) {
          """
        )
        if reducerScopes.isEmpty {
          decls.append(
            """
            ComposableArchitecture.EmptyReducer<Self.State, Self.Action>()
            """)
        } else {
          decls.append(
            """
            \(raw: reducerScopes.joined(separator: "\n"))

            """)
        }
        decls.append("}")
      }
      if !typeNames.contains("CaseScope") {
        decls.append(
          """
          \(access)enum CaseScope {
          \(raw: storeCases.joined(separator: "\n"))
          }
          """
        )
      }
      if !declaration.memberBlock.members.contains(
        where: { $0.as(FunctionDeclSyntax.self)?.name.text == "scope" }
      ) {
        decls.append(
          """
          \(access)static func scope(\
          _ store: ComposableArchitecture.Store<Self.State, Self.Action>\
          ) -> CaseScope {
          switch store.state {
          \(raw: storeScopes.joined(separator: "\n"))
          }
          }
          """
        )
      }
      return decls
    } else {
      if let arguments = node.arguments {
        context.diagnose(
          Diagnostic(
            node: arguments,
            message: MacroExpansionErrorMessage(
              "Argument passed to call that takes no arguments when applied to a struct"
            ),
            fixIt: .replace(
              message: MacroExpansionFixItMessage("Remove '(\(arguments))'"),
              oldNode: node,
              newNode:
                node
                .with(\.leftParen, nil)
                .with(\.arguments, nil)
                .with(\.rightParen, nil)
            )
          )
        )
      }
      if !hasState && !hasExplicitReducerBody {
        decls.append(
          """
          @ObservableState
          \(access)struct State: Codable, Equatable, Hashable, Sendable {
          \(access)init() {}
          }
          """
        )
      }
      if !hasAction && !hasExplicitReducerBody {
        decls.append("\(access)enum Action: Equatable, Hashable, Sendable {}")
      }
      if !hasBody {
        decls.append("\(access)let body = ComposableArchitecture.EmptyReducer<State, Action>()")
      }
      return decls
    }
  }
}

private struct ReducerCase {
  let element: EnumCaseElementSyntax
  let attribute: Attribute?

  enum Attribute {
    case ephemeral
    case ignored
  }
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

extension EnumCaseDeclSyntax {
  fileprivate var attribute: ReducerCase.Attribute? {
    if self.isIgnored {
      return .ignored
    } else if self.isEphemeral {
      return .ephemeral
    } else {
      return nil
    }
  }

  fileprivate var isIgnored: Bool {
    self.attributes.contains("ReducerCaseIgnored")
      || self.elements.contains { $0.parameterClause?.parameters.count != 1 }
  }

  fileprivate var isEphemeral: Bool {
    self.attributes.contains("ReducerCaseEphemeral")
      || self.elements.contains {
        guard
          let parameterClause = $0.parameterClause,
          parameterClause.parameters.count == 1,
          let parameter = parameterClause.parameters.first,
          parameter.type.as(IdentifierTypeSyntax.self)?.isEphemeral == true
        else { return false }
        return true
      }
  }
}

extension EnumCaseElementSyntax {
  fileprivate func suffixed(_ suffix: TokenSyntax) -> Self {
    var element = self
    if var parameterClause = element.parameterClause,
      let type = parameterClause.parameters.first?.type
    {
      let type = MemberTypeSyntax(baseType: type, name: suffix)
      parameterClause.parameters[parameterClause.parameters.startIndex].type = TypeSyntax(type)
      element.parameterClause = parameterClause
    }
    return element
  }
}

extension AttributeListSyntax {
  fileprivate func contains(_ name: TokenSyntax) -> Bool {
    self.contains {
      guard
        case let .attribute(attribute) = $0,
        attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == name.text
      else { return false }
      return true
    }
  }
}

enum ReducerCaseEphemeralMacro: PeerMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
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
