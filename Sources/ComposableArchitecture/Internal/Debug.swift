import Foundation

func debugOutput(_ value: Any, indent: Int = 0) -> String {
  var visitedItems: Set<ObjectIdentifier> = []

  func debugOutputHelp(_ value: Any, indent: Int = 0) -> String {
    let mirror = Mirror(reflecting: value)
    switch (value, mirror.displayStyle) {
    case let (value as CustomDebugOutputConvertible, _):
      return value.debugOutput.indent(by: indent)
    case (_, .collection?):
      return """
        [
        \(mirror.children.map { "\(debugOutput($0.value, indent: 2)),\n" }.joined())]
        """
        .indent(by: indent)

    case (_, .dictionary?):
      let pairs = mirror.children.map { label, value -> String in
        let pair = value as! (key: AnyHashable, value: Any)
        return
          "\("\(debugOutputHelp(pair.key.base)): \(debugOutputHelp(pair.value)),".indent(by: 2))\n"
      }
      return """
        [
        \(pairs.sorted().joined())]
        """
        .indent(by: indent)

    case (_, .set?):
      return """
        Set([
        \(mirror.children.map { "\(debugOutputHelp($0.value, indent: 2)),\n" }.sorted().joined())])
        """
        .indent(by: indent)

    case (_, .optional?):
      return mirror.children.isEmpty
        ? "nil".indent(by: indent)
        : debugOutputHelp(mirror.children.first!.value, indent: indent)

    case (_, .enum?) where !mirror.children.isEmpty:
      let child = mirror.children.first!
      let childMirror = Mirror(reflecting: child.value)
      let elements =
        childMirror.displayStyle != .tuple
        ? debugOutputHelp(child.value, indent: 2)
        : childMirror.children.map { child -> String in
          let label = child.label!
          return "\(label.hasPrefix(".") ? "" : "\(label): ")\(debugOutputHelp(child.value))"
        }
        .joined(separator: ",\n")
        .indent(by: 2)
      return """
        \(mirror.subjectType).\(child.label!)(
        \(elements)
        )
        """
        .indent(by: indent)

    case (_, .enum?):
      return """
        \(mirror.subjectType).\(value)
        """
        .indent(by: indent)

    case (_, .struct?) where !mirror.children.isEmpty:
      let elements = mirror.children
        .map { "\($0.label.map { "\($0): " } ?? "")\(debugOutputHelp($0.value))".indent(by: 2) }
        .joined(separator: ",\n")
      return """
        \(mirror.subjectType)(
        \(elements)
        )
        """
        .indent(by: indent)

    case let (value as AnyObject, .class?)
    where !mirror.children.isEmpty && !visitedItems.contains(ObjectIdentifier(value)):
      visitedItems.insert(ObjectIdentifier(value))
      let elements = mirror.children
        .map { "\($0.label.map { "\($0): " } ?? "")\(debugOutputHelp($0.value))".indent(by: 2) }
        .joined(separator: ",\n")
      return """
        \(mirror.subjectType)(
        \(elements)
        )
        """
        .indent(by: indent)

    case let (value as AnyObject, .class?)
    where !mirror.children.isEmpty && visitedItems.contains(ObjectIdentifier(value)):
      return "\(mirror.subjectType)(↩︎)"

    case let (value as CustomStringConvertible, .class?):
      return value.description
        .replacingOccurrences(
          of: #"^<([^:]+): 0x[^>]+>$"#, with: "$1()", options: .regularExpression
        )
        .indent(by: indent)

    case let (value as CustomDebugStringConvertible, _):
      return value.debugDescription
        .replacingOccurrences(
          of: #"^<([^:]+): 0x[^>]+>$"#, with: "$1()", options: .regularExpression
        )
        .indent(by: indent)

    case let (value as CustomStringConvertible, _):
      return value.description
        .indent(by: indent)

    case (_, .struct?), (_, .class?):
      return "\(mirror.subjectType)()"
        .indent(by: indent)

    case (_, .tuple?) where mirror.children.isEmpty:
      return "()"
        .indent(by: indent)

    case (_, .tuple?):
      let elements = mirror.children.map { child -> String in
        let label = child.label!
        return "\(label.hasPrefix(".") ? "" : "\(label): ")\(debugOutputHelp(child.value))"
          .indent(by: 2)
      }
      return """
        (
        \(elements.joined(separator: ",\n"))
        )
        """
        .indent(by: indent)

    case (_, nil):
      return "\(value)"
        .indent(by: indent)

    @unknown default:
      return "\(value)"
        .indent(by: indent)
    }
  }

  return debugOutputHelp(value, indent: indent)
}

func debugDiff<T>(_ before: T, _ after: T, printer: (T) -> String = { debugOutput($0) }) -> String?
{
  diff(printer(before), printer(after))
}

extension String {
  func indent(by indent: Int) -> String {
    let indentation = String(repeating: " ", count: indent)
    return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
  }
}

public protocol CustomDebugOutputConvertible {
  var debugOutput: String { get }
}

extension Date: CustomDebugOutputConvertible {
  public var debugOutput: String {
    dateFormatter.string(from: self)
  }
}

private let dateFormatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone(identifier: "UTC")!
  return formatter
}()

extension URL: CustomDebugOutputConvertible {
  public var debugOutput: String {
    self.absoluteString
  }
}

#if DEBUG
  #if canImport(Speech)
    import Speech
    extension SFSpeechRecognizerAuthorizationStatus: CustomDebugOutputConvertible {
      public var debugOutput: String {
        switch self {
        case .notDetermined:
          return "notDetermined"
        case .denied:
          return "denied"
        case .restricted:
          return "restricted"
        case .authorized:
          return "authorized"
        @unknown default:
          return "unknown"
        }
      }
    }
  #endif
#endif
