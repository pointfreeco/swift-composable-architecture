import Foundation

/// Prints out a short label of given action leaving out large structs and arrays:
/// Like .action1(.action2(...))
func shortActionLabel(_ a: Any) -> String {
  let m = Mirror(reflecting: a)
  switch m.displayStyle {
  case .enum:
    if let child = m.children.first {
      let childLabel = child.label ?? ""
      let valueLabel = shortActionLabel(child.value)
      return "." + childLabel + "(" + valueLabel + ")"
    }
    
    return ".\(a)"
    
  case .tuple:
    let arguments = m.children.map { label, value in
      let childOutput = shortActionLabel(value)
      return "\(label.map { "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")"
    }
    .joined(separator: ", ")
    return arguments
    
  case .collection:
    return "[...]"
    
  case .set:
    return  "{...}"
    
  case .dictionary:
    return "[ : ]"
    
  case .struct:
    return " \(m.subjectType)(...) "
    
  case .class:
    return " \(m.subjectType)(...) "
    
  case .optional:
    return " \(m.subjectType)(...) "
    
  case .none:
    return String(describing: a)
    
  case .some:
    return "..."
  }
}
