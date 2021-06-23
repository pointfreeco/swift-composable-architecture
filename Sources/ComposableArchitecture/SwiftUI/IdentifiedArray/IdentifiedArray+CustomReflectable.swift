extension IdentifiedArray: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(self, unlabeledChildren: Array(self), displayStyle: .collection)
  }
}
