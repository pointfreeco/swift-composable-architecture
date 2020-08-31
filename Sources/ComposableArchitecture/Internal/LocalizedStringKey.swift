import SwiftUI

extension LocalizedStringKey {
  // NB: `LocalizedStringKey` conforms to `Equatable` but returns false for 2 equivalent format strings.
  //
  func formatted(locale: Locale? = nil) -> String {
    let children = Array(Mirror(reflecting: self).children)
    let key = children[0].value as! String
    let arguments: [CVarArg] = (children[2].value as! [Any])
      .map {
        let children = Array(Mirror(reflecting: $0).children)
        let value = children[0].value as! CVarArg
        let formatter = children[1].value as? Formatter
        return formatter?.string(for: value) ?? value
      }

    return String(format: key, locale: nil, arguments: arguments)
  }
}
