
public func _debugCaseOutput(
  _ value: Any,
  abbreviated: Bool = false
) -> String {
  func debugCaseOutputHelp(_ value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .enum:
      guard let child = mirror.children.first else {
        let childOutput = "\(value)"
        return childOutput == "\(typeName(type(of: value)))" ? "" : ".\(childOutput)"
      }
      let childOutput = debugCaseOutputHelp(child.value)
      return ".\(child.label ?? "")\(childOutput.isEmpty ? "" : "(\(childOutput))")"
    case .tuple:
      return mirror.children.map { label, value in
        let childOutput = debugCaseOutputHelp(value)
        return
          "\(label.map { isUnlabeledArgument($0) ? "_:" : "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")"
      }
      .joined(separator: ", ")
    default:
      return ""
    }
  }

  return (value as? CustomDebugStringConvertible)?.debugDescription
    ?? "\(abbreviated ? "" : typeName(type(of: value)))\(debugCaseOutputHelp(value))"
}

private func isUnlabeledArgument(_ label: String) -> Bool {
  label.firstIndex(where: { $0 != "." && !$0.isNumber }) == nil
}
