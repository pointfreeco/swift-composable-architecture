import Foundation

func debugOutput(_ value: Any, indent: Int = 0) -> String {
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
      return "\("\(debugOutput(pair.key.base)): \(debugOutput(pair.value)),".indent(by: 2))\n"
    }
    return """
      [
      \(pairs.sorted().joined())]
      """
      .indent(by: indent)
  case (_, .set?):
    return """
      Set([
      \(mirror.children.map { "\(debugOutput($0.value, indent: 2)),\n" }.sorted().joined())])
      """
      .indent(by: indent)
  case (_, .optional?):
    return mirror.children.isEmpty
      ? "nil".indent(by: indent)
      : debugOutput(mirror.children.first!.value, indent: indent)
  case (_, .enum?) where !mirror.children.isEmpty:
    let child = mirror.children.first!
    let childMirror = Mirror(reflecting: child.value)
    let elements =
      childMirror.displayStyle != .tuple
      ? debugOutput(child.value, indent: 2)
      : childMirror.children.map { child -> String in
        let label = child.label!
        return "\(label.hasPrefix(".") ? "" : "\(label): ")\(debugOutput(child.value))"
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
  case (_, .struct?) where !mirror.children.isEmpty, (_, .class?) where !mirror.children.isEmpty:
    let elements = mirror.children
      .map { "\($0.label.map { "\($0): " } ?? "")\(debugOutput($0.value))".indent(by: 2) }
      .joined(separator: ",\n")
    return """
      \(mirror.subjectType)(
      \(elements)
      )
      """
      .indent(by: indent)
  case let (value as CustomStringConvertible, .class?):
    return value.description
      .replacingOccurrences(of: #"^<([^:]+): 0x[^>]+>$"#, with: "$1()", options: .regularExpression)
      .indent(by: indent)
  case let (value as CustomDebugStringConvertible, _):
    return value.debugDescription
      .replacingOccurrences(of: #"^<([^:]+): 0x[^>]+>$"#, with: "$1()", options: .regularExpression)
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
      return "\(label.hasPrefix(".") ? "" : "\(label): ")\(debugOutput(child.value))".indent(by: 2)
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

extension DispatchQueue: CustomDebugOutputConvertible {
  public var debugOutput: String {
    switch (self, self.label) {
    case (.main, _): return "DispatchQueue.main"
    case (_, "com.apple.root.default-qos"): return "DispatchQueue.global()"
    case (_, _) where self.label == "com.apple.root.\(self.qos.qosClass)-qos":
      return "DispatchQueue.global(qos: .\(self.qos.qosClass))"
    default:
      return "DispatchQueue(label: \(self.label.debugDescription), qos: .\(self.qos.qosClass))"
    }
  }
}

extension Effect: CustomDebugOutputConvertible {
  public var debugOutput: String {
    var empty: Any?
    var just: Any?
    var mergeMany: [Any] = []
    var path: [String] = []
    var transform: Any?

    func updatePath(_ value: Any) {
      let mirror = Mirror(reflecting: value)
      let subjectType = "\(mirror.subjectType)"

      //      if subjectType.hasPrefix("Deferred<"), let value = value as? Invokable {
      //        updatePath(value())
      //      }
      if subjectType.hasPrefix("Concatenate<") {
        let prefix = mirror.children.first(where: { label, _ in label == "prefix" })!.value
        let suffix = mirror.children.first(where: { label, _ in label == "suffix" })!.value
        mergeMany.append(contentsOf: [prefix, suffix])
        return
      }
      if subjectType.hasPrefix("Delay<") {
        let interval = mirror.children.first(where: { label, _ in label == "interval" })!.value
        let scheduler = mirror.children.first(where: { label, _ in label == "scheduler" })!.value
        let ns = Int("\(Mirror(reflecting: interval).children.first!.value)")!
        path.append(
          "\n.delay(for: \(Double(ns) / Double(NSEC_PER_SEC)), scheduler: \(ComposableArchitecture.debugOutput(scheduler)))"
        )
      }
      if subjectType.hasPrefix("Empty<") {
        let completeImmediately = mirror.children.first(where: { label, _ in
          label == "completeImmediately"
        })!.value
        empty = completeImmediately
      }
      if subjectType.hasPrefix("Just<") {
        just = mirror.children.first!.value
      }
      if subjectType.hasPrefix("Map<") {
        transform = mirror.children.first(where: { label, _ in label == "transform" })!.value
      }
      if subjectType.hasPrefix("MergeMany<") {
        let publishers = mirror.children.first(where: { label, _ in label == "publishers" })!.value
        mergeMany.append(contentsOf: Mirror(reflecting: publishers).children.map { $0.value })
        return
      }
      if subjectType.hasPrefix("ReceiveOn<") {
        let scheduler = mirror.children.first(where: { label, _ in label == "scheduler" })!.value
        path.append("\n.receive(on: \(ComposableArchitecture.debugOutput(scheduler)))")
      }

      mirror.children.forEach { _, v in updatePath(v) }
    }

    updatePath(self)

    guard mergeMany.isEmpty else {
      return
        ComposableArchitecture
        .debugOutput(mergeMany.filter { !ComposableArchitecture.debugOutput($0).isEmpty })
    }
    guard empty == nil else { return "" }

    if let value = just, let transform = transform {
      let transform = withUnsafePointer(to: transform) {
        $0.withMemoryRebound(to: ((Any) -> Output).self, capacity: 1, { $0.pointee })
      }
      just = transform(value)
    }

    let operators = path.reversed().joined()
    return """
      \(type(of: self))(\
      \(just.map { "\n\("value: \(ComposableArchitecture.debugOutput($0))".indent(by: 2))\n" } ?? "")\
      )\(operators.indent(by: !operators.isEmpty && just == nil ? 2 : 0))
      """
  }
}

extension OperationQueue: CustomDebugOutputConvertible {
  public var debugOutput: String {
    switch (self, self.name) {
    case (.main, _): return "OperationQueue.main"
    default: return "OperationQueue()"
    }
  }
}

extension RunLoop: CustomDebugOutputConvertible {
  public var debugOutput: String {
    switch self {
    case .main: return "RunLoop.main"
    default: return "RunLoop()"
    }
  }
}

extension URL: CustomDebugOutputConvertible {
  public var debugOutput: String {
    self.absoluteString
  }
}

#if canImport(CoreLocation)
  import CoreLocation
  extension CLAuthorizationStatus: CustomDebugOutputConvertible {
    public var debugOutput: String {
      switch self {
      case .notDetermined:
        return "notDetermined"
      case .restricted:
        return "restricted"
      case .denied:
        return "denied"
      case .authorizedAlways:
        return "authorizedAlways"
      case .authorizedWhenInUse:
        return "authorizedWhenInUse"
      @unknown default:
        return "unknown"
      }
    }
  }
#endif

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
