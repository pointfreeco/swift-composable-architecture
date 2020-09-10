import SwiftUI

extension LocalizedStringKey: CustomDebugOutputConvertible {
  // NB: `LocalizedStringKey` conforms to `Equatable` but returns false for equivalent format strings.
  public func formatted(locale: Locale? = nil) -> String {
    let children = Array(Mirror(reflecting: self).children)
    let key = children[0].value as! String
    let arguments: [CVarArg] = Array(Mirror(reflecting: children[2].value).children)
      .compactMap {
        let children = Array(Mirror(reflecting: $0.value).children)
        let value: Any
        let formatter: Formatter?
        // `LocalizedStringKey.FormatArgument` differs depending on OS/platform.
        if children[0].label == "storage" {
          (value, formatter) =
            Array(Mirror(reflecting: children[0].value).children)[0].value as! (Any, Formatter?)
        } else {
          value = children[0].value
          formatter = children[1].value as? Formatter
        }
        return formatter?.string(for: value) ?? value as! CVarArg
      }

    return String(format: key, locale: nil, arguments: arguments)
  }

  public var debugOutput: String {
    self.formatted().debugDescription
  }
}
