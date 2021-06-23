extension IdentifiedArray: Hashable where Element: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self._dictionary.keys)
  }
}
