extension IdentifiedArray: Hashable where Element: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.count)
    for element in self {
      hasher.combine(element)
    }
  }
}
