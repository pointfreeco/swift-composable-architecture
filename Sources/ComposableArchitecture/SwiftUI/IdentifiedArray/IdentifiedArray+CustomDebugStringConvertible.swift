extension IdentifiedArray: CustomDebugStringConvertible {
  public var debugDescription: String {
    var result = "IdentifiedArray<\(Element.self)>(["
    var first = true
    for item in self {
      if first {
        first = false
      } else {
        result += ", "
      }
      debugPrint(item, terminator: "", to: &result)
    }
    result += "])"
    return result
  }
}
