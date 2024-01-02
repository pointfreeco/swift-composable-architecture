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
import SwiftSyntaxMacros

public struct PerceptibleMacro {
  static let moduleName = "Perception"

  static let conformanceName = "Perceptible"
  static var qualifiedConformanceName: String {
    return "\(moduleName).\(conformanceName)"
  }

  static var perceptibleConformanceType: TypeSyntax {
    "\(raw: qualifiedConformanceName)"
  }

  static let registrarTypeName = "PerceptionRegistrar"
  static var qualifiedRegistrarTypeName: String {
    return "\(moduleName).\(registrarTypeName)"
  }

  static let trackedMacroName = "PerceptionTracked"
  static let ignoredMacroName = "PerceptionIgnored"

  static let registrarVariableName = "_$perceptionRegistrar"

  static func registrarVariable(_ perceptibleType: TokenSyntax) -> DeclSyntax {
    return
      """
      @\(raw: ignoredMacroName) private let \(raw: registrarVariableName) = \(raw: qualifiedRegistrarTypeName)()
      """
  }

  static func accessFunction(_ perceptibleType: TokenSyntax) -> DeclSyntax {
    return
      """
      internal nonisolated func access<Member>(
          keyPath: KeyPath<\(perceptibleType), Member>
      ) {
        \(raw: registrarVariableName).access(self, keyPath: keyPath)
      }
      """
  }

  static func withMutationFunction(_ perceptibleType: TokenSyntax) -> DeclSyntax {
    return
      """
      internal nonisolated func withMutation<Member, MutationResult>(
        keyPath: KeyPath<\(perceptibleType), Member>,
        _ mutation: () throws -> MutationResult
      ) rethrows -> MutationResult {
        try \(raw: registrarVariableName).withMutation(of: self, keyPath: keyPath, mutation)
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

struct PerceptionDiagnostic: DiagnosticMessage {
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
    syntax: S, message: String, domain: String = "Perception", id: PerceptionDiagnostic.ID,
    severity: SwiftDiagnostics.DiagnosticSeverity = .error
  ) {
    self.init(diagnostics: [
      Diagnostic(
        node: Syntax(syntax),
        message: PerceptionDiagnostic(message: message, domain: domain, id: id, severity: severity))
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
          case .fileprivate, .private, .internal, .public:
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

  var isValidForPerception: Bool {
    !isComputed && isInstance && !isImmutable && identifier != nil
  }
}

extension PerceptibleMacro: MemberMacro {
  public static func expansion<
    Declaration: DeclGroupSyntax,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else {
      return []
    }

    let perceptibleType = identified.name

    if declaration.isEnum {
      // enumerations cannot store properties
      throw DiagnosticsError(
        syntax: node,
        message: "'@Perceptible' cannot be applied to enumeration type '\(perceptibleType.text)'",
        id: .invalidApplication)
    }
    if declaration.isStruct {
      // structs are not yet supported; copying/mutation semantics tbd
      throw DiagnosticsError(
        syntax: node,
        message: "'@Perceptible' cannot be applied to struct type '\(perceptibleType.text)'",
        id: .invalidApplication)
    }
    if declaration.isActor {
      // actors cannot yet be supported for their isolation
      throw DiagnosticsError(
        syntax: node,
        message: "'@Perceptible' cannot be applied to actor type '\(perceptibleType.text)'",
        id: .invalidApplication)
    }

    var declarations = [DeclSyntax]()

    declaration.addIfNeeded(PerceptibleMacro.registrarVariable(perceptibleType), to: &declarations)
    declaration.addIfNeeded(PerceptibleMacro.accessFunction(perceptibleType), to: &declarations)
    declaration.addIfNeeded(
      PerceptibleMacro.withMutationFunction(perceptibleType), to: &declarations)

    return declarations
  }
}

extension PerceptibleMacro: MemberAttributeMacro {
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
    guard let property = member.as(VariableDeclSyntax.self), property.isValidForPerception,
      property.identifier != nil
    else {
      return []
    }

    // dont apply to ignored properties or properties that are already flagged as tracked
    if property.hasMacroApplication(PerceptibleMacro.ignoredMacroName)
      || property.hasMacroApplication(PerceptibleMacro.trackedMacroName)
    {
      return []
    }

    return [
      AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier(PerceptibleMacro.trackedMacroName)))
    ]
  }
}

extension PerceptibleMacro: ExtensionMacro {
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

    let decl: DeclSyntax = """
      extension \(raw: type.trimmedDescription): \(raw: qualifiedConformanceName) {}
      """
    let obsDecl: DeclSyntax = """
      @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
      extension \(raw: type.trimmedDescription): Observation.Observable {}
      """
    let ext = decl.cast(ExtensionDeclSyntax.self)
    let obsExt = obsDecl.cast(ExtensionDeclSyntax.self)

    if let availability = declaration.attributes.availability {
      return [
        ext.with(\.attributes, availability),
        obsExt.with(\.attributes, availability),
      ]
    } else {
      return [
        ext,
        obsExt,
      ]
    }
  }
}

public struct PerceptionTrackedMacro: AccessorMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: Declaration,
    in context: Context
  ) throws -> [AccessorDeclSyntax] {
    guard let property = declaration.as(VariableDeclSyntax.self),
      property.isValidForPerception,
      let identifier = property.identifier
    else {
      return []
    }

    if property.hasMacroApplication(PerceptibleMacro.ignoredMacroName) {
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
        access(keyPath: \\.\(identifier))
        return _\(identifier)
      }
      """

    let setAccessor: AccessorDeclSyntax =
      """
      set {
        withMutation(keyPath: \\.\(identifier)) {
          _\(identifier) = newValue
        }
      }
      """

    return [initAccessor, getAccessor, setAccessor]
  }
}

extension PerceptionTrackedMacro: PeerMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: SwiftSyntax.AttributeSyntax,
    providingPeersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    guard let property = declaration.as(VariableDeclSyntax.self),
      property.isValidForPerception
    else {
      return []
    }

    if property.hasMacroApplication(PerceptibleMacro.ignoredMacroName)
      || property.hasMacroApplication(PerceptibleMacro.trackedMacroName)
    {
      return []
    }

    let storage = DeclSyntax(
      property.privatePrefixed("_", addingAttribute: PerceptibleMacro.ignoredAttribute))
    return [storage]
  }
}

public struct PerceptionIgnoredMacro: AccessorMacro {
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
