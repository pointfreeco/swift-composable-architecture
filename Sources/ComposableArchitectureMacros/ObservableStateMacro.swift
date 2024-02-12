//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ObservableStateMacro {
  static let moduleName = "ComposableArchitecture"

  static let conformanceName = "ObservableState"
  static var qualifiedConformanceName: String {
    return "\(moduleName).\(conformanceName)"
  }
  static let originalConformanceName = "Observable"
  static var qualifiedOriginalConformanceName: String {
    "Observation.\(originalConformanceName)"
  }

  static var observableConformanceType: TypeSyntax {
    "\(raw: qualifiedConformanceName)"
  }

  static let registrarTypeName = "ObservationStateRegistrar"
  static var qualifiedRegistrarTypeName: String {
    "\(moduleName).\(registrarTypeName)"
  }

  static let idName = "ObservableStateID"
  static var qualifiedIDName: String {
    "\(moduleName).\(idName)"
  }

  static let trackedMacroName = "ObservationStateTracked"
  static let ignoredMacroName = "ObservationStateIgnored"
  static let presentsMacroName = "Presents"
  static let presentationStatePropertyWrapperName = "PresentationState"

  static let registrarVariableName = "_$observationRegistrar"

  static func registrarVariable(_ observableType: TokenSyntax) -> DeclSyntax {
    return
      """
      @\(raw: ignoredMacroName) var \(raw: registrarVariableName) = \(raw: qualifiedRegistrarTypeName)()
      """
  }

  static func idVariable() -> DeclSyntax {
    return
      """
      public var _$id: \(raw: qualifiedIDName) {
      \(raw: registrarVariableName).id
      }
      """
  }

  static func willModifyFunction() -> DeclSyntax {
    return
      """
      public mutating func _$willModify() {
      \(raw: registrarVariableName)._$willModify()
      }
      """
  }

  static var ignoredAttribute: AttributeSyntax {
    AttributeSyntax(
      leadingTrivia: .space,
      atSign: .atSignToken(),
      attributeName: IdentifierTypeSyntax(name: .identifier(ignoredMacroName)),
      trailingTrivia: .space
    )
  }
}

struct ObservationDiagnostic: DiagnosticMessage {
  enum ID: String {
    case invalidApplication = "invalid type"
    case missingInitializer = "missing initializer"
  }

  var message: String
  var diagnosticID: MessageID
  var severity: DiagnosticSeverity

  init(
    message: String, diagnosticID: SwiftDiagnostics.MessageID,
    severity: SwiftDiagnostics.DiagnosticSeverity = .error
  ) {
    self.message = message
    self.diagnosticID = diagnosticID
    self.severity = severity
  }

  init(
    message: String, domain: String, id: ID, severity: SwiftDiagnostics.DiagnosticSeverity = .error
  ) {
    self.message = message
    self.diagnosticID = MessageID(domain: domain, id: id.rawValue)
    self.severity = severity
  }
}

extension DiagnosticsError {
  init<S: SyntaxProtocol>(
    syntax: S, message: String, domain: String = "Observation", id: ObservationDiagnostic.ID,
    severity: SwiftDiagnostics.DiagnosticSeverity = .error
  ) {
    self.init(diagnostics: [
      Diagnostic(
        node: Syntax(syntax),
        message: ObservationDiagnostic(message: message, domain: domain, id: id, severity: severity)
      )
    ])
  }
}

extension DeclModifierListSyntax {
  func privatePrefixed(_ prefix: String) -> DeclModifierListSyntax {
    let modifier: DeclModifierSyntax = DeclModifierSyntax(name: "private", trailingTrivia: .space)
    return [modifier]
      + filter {
        switch $0.name.tokenKind {
        case .keyword(let keyword):
          switch keyword {
          case .fileprivate, .private, .internal, .public, .package:
            return false
          default:
            return true
          }
        default:
          return true
        }
      }
  }

  init(keyword: Keyword) {
    self.init([DeclModifierSyntax(name: .keyword(keyword))])
  }
}

extension TokenSyntax {
  func privatePrefixed(_ prefix: String) -> TokenSyntax {
    switch tokenKind {
    case .identifier(let identifier):
      return TokenSyntax(
        .identifier(prefix + identifier), leadingTrivia: leadingTrivia,
        trailingTrivia: trailingTrivia, presence: presence)
    default:
      return self
    }
  }
}

extension PatternBindingListSyntax {
  func privatePrefixed(_ prefix: String) -> PatternBindingListSyntax {
    var bindings = self.map { $0 }
    for index in 0..<bindings.count {
      let binding = bindings[index]
      if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
        bindings[index] = PatternBindingSyntax(
          leadingTrivia: binding.leadingTrivia,
          pattern: IdentifierPatternSyntax(
            leadingTrivia: identifier.leadingTrivia,
            identifier: identifier.identifier.privatePrefixed(prefix),
            trailingTrivia: identifier.trailingTrivia
          ),
          typeAnnotation: binding.typeAnnotation,
          initializer: binding.initializer,
          accessorBlock: binding.accessorBlock,
          trailingComma: binding.trailingComma,
          trailingTrivia: binding.trailingTrivia)

      }
    }

    return PatternBindingListSyntax(bindings)
  }
}

extension VariableDeclSyntax {
  func privatePrefixed(_ prefix: String, addingAttribute attribute: AttributeSyntax)
    -> VariableDeclSyntax
  {
    let newAttributes = attributes + [.attribute(attribute)]
    return VariableDeclSyntax(
      leadingTrivia: leadingTrivia,
      attributes: newAttributes,
      modifiers: modifiers.privatePrefixed(prefix),
      bindingSpecifier: TokenSyntax(
        bindingSpecifier.tokenKind, leadingTrivia: .space, trailingTrivia: .space,
        presence: .present),
      bindings: bindings.privatePrefixed(prefix),
      trailingTrivia: trailingTrivia
    )
  }

  var isValidForObservation: Bool {
    !isComputed && isInstance && !isImmutable && identifier != nil
  }
}

extension ObservableStateMacro: MemberMacro {
  public static func expansion<
    Declaration: DeclGroupSyntax,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    guard !declaration.isEnum
    else {
      return try enumExpansion(of: node, providingMembersOf: declaration, in: context)
    }

    guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else {
      return []
    }

    let observableType = identified.name.trimmed

    if declaration.isClass {
      // classes are not supported
      throw DiagnosticsError(
        syntax: node,
        message: "'@ObservableState' cannot be applied to class type '\(observableType.text)'",
        id: .invalidApplication)
    }
    if declaration.isActor {
      // actors cannot yet be supported for their isolation
      throw DiagnosticsError(
        syntax: node,
        message: "'@ObservableState' cannot be applied to actor type '\(observableType.text)'",
        id: .invalidApplication)
    }

    var declarations = [DeclSyntax]()

    let access = declaration.modifiers.first {
      $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.package)
    }
    declaration.addIfNeeded(
      ObservableStateMacro.registrarVariable(observableType), to: &declarations)
    declaration.addIfNeeded(ObservableStateMacro.idVariable(), to: &declarations)
    declaration.addIfNeeded(ObservableStateMacro.willModifyFunction(), to: &declarations)

    return declarations
  }
}

extension ObservableStateMacro {
  public static func enumExpansion<
    Declaration: DeclGroupSyntax,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    let enumCaseDecls = declaration.memberBlock.members
      .flatMap { $0.decl.as(EnumCaseDeclSyntax.self)?.elements ?? [] }
    var getCases: [String] = []
    var willModifyCases: [String] = []
    for (tag, enumCaseDecl) in enumCaseDecls.enumerated() {
      // TODO: Support multiple parameters of observable state?
      if let parameters = enumCaseDecl.parameterClause?.parameters,
        parameters.count == 1,
        let parameter = parameters.first
      {
        getCases.append(
          """
          case let .\(enumCaseDecl.name.text)(state):
          return ._$id(for: state)._$tag(\(tag))
          """
        )
        willModifyCases.append(
          """
          case var .\(enumCaseDecl.name.text)(state):
          \(moduleName)._$willModify(&state)
          self = .\(enumCaseDecl.name.text)(\(parameter.firstName.map { "\($0): " } ?? "")state)
          """
        )
      } else {
        getCases.append(
          """
          case .\(enumCaseDecl.name.text):
          return ._$inert._$tag(\(tag))
          """
        )
        willModifyCases.append(
          """
          case .\(enumCaseDecl.name.text):
          break
          """
        )
      }
    }

    return [
      """
      public var _$id: \(raw: qualifiedIDName) {
      switch self {
      \(raw: getCases.joined(separator: "\n"))
      }
      }
      """,
      """
      public mutating func _$willModify() {
      switch self {
      \(raw: willModifyCases.joined(separator: "\n"))
      }
      }
      """,
    ]
  }
}

extension SyntaxStringInterpolation {
  // It would be nice for SwiftSyntaxBuilder to provide this out-of-the-box.
  mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
    if let node {
      appendInterpolation(node)
    }
  }
}

extension ObservableStateMacro: MemberAttributeMacro {
  public static func expansion<
    Declaration: DeclGroupSyntax,
    MemberDeclaration: DeclSyntaxProtocol,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    attachedTo declaration: Declaration,
    providingAttributesFor member: MemberDeclaration,
    in context: Context
  ) throws -> [AttributeSyntax] {
    guard let property = member.as(VariableDeclSyntax.self), property.isValidForObservation,
      property.identifier != nil
    else {
      return []
    }

    // dont apply to ignored properties or properties that are already flagged as tracked
    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName)
      || property.hasMacroApplication(ObservableStateMacro.trackedMacroName)
    {
      return []
    }

    property.diagnose(
      attribute: "ObservationIgnored",
      renamed: ObservableStateMacro.ignoredMacroName,
      context: context
    )
    property.diagnose(
      attribute: "ObservationTracked",
      renamed: ObservableStateMacro.trackedMacroName,
      context: context
    )
    property.diagnose(
      attribute: "PresentationState",
      renamed: ObservableStateMacro.presentsMacroName,
      context: context
    )

    if property.hasMacroApplication(ObservableStateMacro.presentsMacroName) {
      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier(ObservableStateMacro.ignoredMacroName)))
      ]
    }

    return [
      AttributeSyntax(
        attributeName: IdentifierTypeSyntax(
          name: .identifier(ObservableStateMacro.trackedMacroName)))
    ]
  }
}

extension VariableDeclSyntax {
  func diagnose<C: MacroExpansionContext>(
    attribute name: String,
    renamed rename: String,
    context: C
  ) {
    if let attribute = self.firstAttribute(for: name) {
      context.diagnose(
        Diagnostic(
          node: attribute,
          message: MacroExpansionErrorMessage("'@\(name)' cannot be used in '@ObservableState'"),
          fixIt: .replace(
            message: MacroExpansionFixItMessage("Use '@\(rename)' instead"),
            oldNode: attribute,
            newNode: attribute.with(
              \.attributeName, TypeSyntax(IdentifierTypeSyntax(name: .identifier(rename)))
            )
          )
        )
      )
    }
  }
}

extension ObservableStateMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // This method can be called twice - first with an empty `protocols` when
    // no conformance is needed, and second with a `MissingTypeSyntax` instance.
    if protocols.isEmpty {
      return []
    }

    return [
      ("""
      \(declaration.attributes.availability)extension \(raw: type.trimmedDescription): \
      \(raw: qualifiedConformanceName), Observation.Observable {}
      """ as DeclSyntax)
      .cast(ExtensionDeclSyntax.self)
    ]
  }
}

public struct ObservationStateTrackedMacro: AccessorMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: Declaration,
    in context: Context
  ) throws -> [AccessorDeclSyntax] {
    guard let property = declaration.as(VariableDeclSyntax.self),
      property.isValidForObservation,
      let identifier = property.identifier?.trimmed
    else {
      return []
    }

    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName)
      || property.hasMacroApplication(ObservableStateMacro.presentationStatePropertyWrapperName)
      || property.hasMacroApplication(ObservableStateMacro.presentsMacroName)
    {
      return []
    }

    let initAccessor: AccessorDeclSyntax =
      """
      @storageRestrictions(initializes: _\(identifier))
      init(initialValue) {
      _\(identifier) = initialValue
      }
      """

    let getAccessor: AccessorDeclSyntax =
      """
      get {
      \(raw: ObservableStateMacro.registrarVariableName).access(self, keyPath: \\.\(identifier))
      return _\(identifier)
      }
      """

    let setAccessor: AccessorDeclSyntax =
      """
      set {
      \(raw: ObservableStateMacro.registrarVariableName).mutate(self, keyPath: \\.\(identifier), &_\(identifier), newValue, _$isIdentityEqual)
      }
      """
    let modifyAccessor: AccessorDeclSyntax = """
      _modify {
        let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.\(identifier), &_\(identifier))
        defer {
          _$observationRegistrar.didModify(self, keyPath: \\.\(identifier), &_\(identifier), oldValue, _$isIdentityEqual)
        }
        yield &_\(identifier)
      }
      """

    return [initAccessor, getAccessor, setAccessor, modifyAccessor]
  }
}

extension ObservationStateTrackedMacro: PeerMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: SwiftSyntax.AttributeSyntax,
    providingPeersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    guard let property = declaration.as(VariableDeclSyntax.self),
      property.isValidForObservation
    else {
      return []
    }

    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName)
      || property.hasMacroApplication(ObservableStateMacro.presentationStatePropertyWrapperName)
      || property.hasMacroApplication(ObservableStateMacro.presentsMacroName)
      || property.hasMacroApplication(ObservableStateMacro.trackedMacroName)
    {
      return []
    }

    let storage = DeclSyntax(
      property.privatePrefixed("_", addingAttribute: ObservableStateMacro.ignoredAttribute))
    return [storage]
  }
}

public struct ObservationStateIgnoredMacro: AccessorMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: Declaration,
    in context: Context
  ) throws -> [AccessorDeclSyntax] {
    return []
  }
}
