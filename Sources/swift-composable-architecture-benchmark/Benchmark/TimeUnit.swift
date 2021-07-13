import Foundation

enum TimeUnit: Int {
  case s = 1
  case ms = 1000
  case µs = 1_000_000
  case ns = 1_000_000_000

  var suffix: String {
    switch self {
    case .s: return "s"
    case .ms: return "ms"
    case .µs: return "µs"
    case .ns: return "ns"
    }
  }

  func format(_ seconds: TimeInterval, signed: Bool = false) -> String {
    let decimal = self == .ns ? ".0f" : ".3f"
    let format = signed ? "%+\(decimal) %@" : "%\(decimal) %@"
    return String(format: format, seconds * Double(rawValue), suffix)
  }

  static func bestUnit(_ duration: TimeInterval) -> TimeUnit {
    if duration > 1 {
      return .s
    } else if duration > 1e-3 {
      return .ms
    } else if duration > 1e-6 {
      return .µs
    } else {
      return .ns
    }
  }

  static func format(_ duration: TimeInterval) -> String {
    bestUnit(duration).format(duration)
  }
}
