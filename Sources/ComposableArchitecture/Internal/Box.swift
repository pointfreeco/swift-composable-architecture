public class Box<Wrapped> {
  public var wrappedValue: Wrapped

  public init(wrappedValue: Wrapped) {
    self.wrappedValue = wrappedValue
  }

  public var boxedValue: Wrapped {
    _read { yield self.wrappedValue }
    _modify { yield &self.wrappedValue }
  }
}
