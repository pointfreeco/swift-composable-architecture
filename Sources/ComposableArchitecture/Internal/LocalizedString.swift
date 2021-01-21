import SwiftUI

extension LocalizedStringKey: CustomDebugOutputConvertible {
  // NB: `LocalizedStringKey` conforms to `Equatable` but returns false for equivalent format
  //     strings. To account for this we reflect on it to extract and string-format its storage.
  func formatted(locale: Locale? = nil) -> String {
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

    return String(format: key, locale: locale, arguments: arguments)
  }

  public var debugOutput: String {
    self.formatted().debugDescription
  }
}

extension Text: CustomDebugOutputConvertible {
  // NB: State like `AlertState` holds onto `Text` that we need to be able to assert against. We
  //     can reflect on its storage to extract and string-format it for these assertions.
  func formatted(locale: Locale? = nil) -> String {
    let outerStorage = Mirror(reflecting: self).children.first!
    let innerStorage = Mirror(reflecting: outerStorage.value).children.first!
    switch innerStorage.label {
    case "anyTextStorage":
      let children = Array(Mirror(reflecting: innerStorage.value).children)
      switch children[0].label {
      case "key":
        let localizedStringKey = children[0].value as! LocalizedStringKey
        return localizedStringKey.formatted(locale: locale)
      case "first":
        let first = children[0].value as! Text
        let second = children[1].value as! Text
        return first.formatted(locale: locale) + second.formatted(locale: locale)
      default:
        fatalError("Unhandled text storage case\(children[0].label.map { ": \($0)" } ?? "")")
      }
    case "verbatim":
      return innerStorage.value as! String
    default:
      fatalError("Unhandled text storage case: \(innerStorage.label.map { ": \($0)" } ?? ""))")
    }
  }

  public var debugOutput: String {
    self.formatted().debugDescription
  }
}
