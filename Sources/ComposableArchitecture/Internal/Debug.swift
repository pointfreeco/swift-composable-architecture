import CustomDump
import Foundation

func debugOutput(_ value: Any, indent: Int = 0) -> String {
  var out = ""
  customDump(value, to: &out, indent: indent)
  return out
}

func debugDiff<T>(_ before: T, _ after: T) -> String? {
  difference(before, after)
}

extension String {
  func indent(by indent: Int) -> String {
    let indentation = String(repeating: " ", count: indent)
    return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
  }
}
