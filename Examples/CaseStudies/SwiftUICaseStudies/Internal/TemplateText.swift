import SwiftUI

extension Text {
  init(template: String, _ style: Font.TextStyle = .body) {
    enum Style: Hashable {
      case code
      case emphasis
      case strong
    }

    var segments: [Text] = []
    var currentValue = ""
    var currentStyles: Set<Style> = []

    func flushSegment() {
      var text = Text(currentValue)
      if currentStyles.contains(.code) {
        text = text.font(.system(style, design: .monospaced))
      }
      if currentStyles.contains(.emphasis) {
        text = text.italic()
      }
      if currentStyles.contains(.strong) {
        text = text.bold()
      }
      segments.append(text)
      currentValue.removeAll()
    }

    for character in template {
      switch character {
      case "*":
        flushSegment()
        currentStyles.toggle(.strong)
      case "_":
        flushSegment()
        currentStyles.toggle(.emphasis)
      case "`":
        flushSegment()
        currentStyles.toggle(.code)
      default:
        currentValue.append(character)
      }
    }
    flushSegment()

    self = segments.reduce(Text(verbatim: ""), +)
  }
}

extension Set {
  fileprivate mutating func toggle(_ element: Element) {
    if self.contains(element) {
      self.remove(element)
    } else {
      self.insert(element)
    }
  }
}
