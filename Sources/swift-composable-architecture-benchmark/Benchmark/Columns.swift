import Foundation

enum Columns: String, Hashable, CaseIterable {
  case label
  case best
  case mean
  case delta
  case variation
  case performance
  case standardError
  case iterations

  var title: String {
    switch self {
    case .label: return ""
    case .best: return ""
    case .mean: return "Duration"
    case .delta: return "Difference"
    case .variation: return "Variation"
    case .performance: return "Performance"
    case .standardError: return "Std.Error"
    case .iterations: return "Iterations"
    }
  }
}
