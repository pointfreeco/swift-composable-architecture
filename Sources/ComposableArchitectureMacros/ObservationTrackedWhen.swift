//import SwiftSyntax
//import SwiftSyntaxMacros
//
//import SwiftDiagnostics
//import SwiftOperators
//import SwiftSyntaxBuilder
//
//public struct ObservationTrackedWhenMacro: AccessorMacro {
//  public static func expansion<Context, Declaration>(
//    of node: SwiftSyntax.AttributeSyntax,
//    providingAccessorsOf declaration: Declaration,
//    in context: Context
//  ) throws -> [SwiftSyntax.AccessorDeclSyntax]
//  where
//  Context : SwiftSyntaxMacros.MacroExpansionContext,
//  Declaration : SwiftSyntax.DeclSyntaxProtocol
//  {
//    guard let property = declaration.as(VariableDeclSyntax.self),
//          property.isValidForObservation,
//          let identifier = property.identifier else {
//      return []
//    }
//
//    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName) {
//      return []
//    }
//
//    let initAccessor: AccessorDeclSyntax =
//      """
//      init(initialValue) initializes(_\(identifier)) {
//        _\(identifier) = initialValue
//      }
//      """
//
//    let getAccessor: AccessorDeclSyntax =
//      """
//      get {
//        access(keyPath: \\.\(identifier))
//        return _\(identifier)
//      }
//      """
//
//    let setAccessor: AccessorDeclSyntax
//    if property.isIdentifiedArray {
//      // TODO: fix force unwraps
//      let function = node.arguments!.as(LabeledExprListSyntax.self)!.first!.expression.as(StringLiteralExprSyntax.self)!.segments.description
//      setAccessor =
//      """
//      set {
//        if \(raw: function)(_\(identifier), newValue) {
//          withMutation(keyPath: \\.\(identifier)) {
//            _\(identifier) = newValue
//          }
//        } else {
//          _\(identifier) = newValue
//        }
//      }
//      """
//    } else {
//      setAccessor =
//      """
//      set {
//        withMutation(keyPath: \\.\(identifier)) {
//          _\(identifier) = newValue
//        }
//      }
//      """
//    }
//
//    return [initAccessor, getAccessor, setAccessor]
//  }
//}
//
//extension ObservationTrackedWhenMacro: PeerMacro {
//  public static func expansion<
//    Context: MacroExpansionContext,
//    Declaration: DeclSyntaxProtocol
//  >(
//    of node: SwiftSyntax.AttributeSyntax,
//    providingPeersOf declaration: Declaration,
//    in context: Context
//  ) throws -> [DeclSyntax] {
//    guard let property = declaration.as(VariableDeclSyntax.self),
//          property.isValidForObservation else {
//      return []
//    }
//
//    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName) ||
//        property.hasMacroApplication(ObservableStateMacro.trackedMacroName) ||
//        property.hasMacroApplication("ObservationTrackedWhen") {
//      return []
//    }
//
//    let storage = DeclSyntax(property.privatePrefixed("_", addingAttribute: ObservableStateMacro.ignoredAttribute))
//    return [storage]
//  }
//}
