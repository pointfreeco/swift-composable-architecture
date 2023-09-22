//@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
public protocol ObservableState {
  var _$id: StateID { get }
}

// TODO: Optimize, benchmark
@available(iOS, introduced: 17)
@available(macOS, introduced: 14)
@available(tvOS, introduced: 17)
@available(watchOS, introduced: 10)
public func isIdentityEqual<T>(_ lhs: T, _ rhs: T) -> Bool {
  if
    let oldID = (lhs as? any ObservableState)?._$id,
    let newID = (rhs as? any ObservableState)?._$id
  {
    return oldID == newID
  } else {

    func open<C: Collection>(_ lhs: C, _ rhs: Any) -> Bool {
      guard let rhs = rhs as? C else { return false }
      return lhs.count == rhs.count
      && zip(lhs, rhs).allSatisfy(isIdentityEqual)
    }

    if
      let lhs = lhs as? any Collection
    {
      return open(lhs, rhs)
    }

    return false
  }
}
