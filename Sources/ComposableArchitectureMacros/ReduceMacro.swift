import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum ReduceMacro {
}

extension ReduceMacro: DeclarationMacro {
  public static func expansion<N: FreestandingMacroExpansionSyntax, C: MacroExpansionContext>(
    of node: N,
    in context: C
  ) throws -> [DeclSyntax] {
    guard let trailingClosure = node.trailingClosure
    else {
      // TODO: fatal error?
      return []
    }
    let isBuilder: Bool
    switch trailingClosure.signature?.parameterClause {
    case let .parameterClause(clause):
      isBuilder = clause.parameters.isEmpty
    case let .simpleInput(parameters):
      isBuilder = parameters.isEmpty
    case .none:
      isBuilder = true
    }
    if isBuilder {
      return [
        """
        @ReducerBuilder<State, Action>
        var body: some Reducer<State, Action> \(trailingClosure.trimmed)
        """
      ]
    } else {
      return [
        """
        var body: some Reducer<Self.State, Self.Action> {
        Reduce<Self.State, Self.Action> \(trailingClosure)
        }
        """
      ]
    }
  }
}
