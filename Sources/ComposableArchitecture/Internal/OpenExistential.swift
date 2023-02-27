#if swift(>=5.7)
  // MARK: swift(>=5.7)
  // MARK: Equatable

  func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    (lhs as? any Equatable)?.isEqual(other: rhs)
  }

  extension Equatable {
    fileprivate func isEqual(other: Any) -> Bool {
      self == other as? Self
    }
  }

  // MARK: Identifiable

  func _id(_ value: Any) -> AnyHashable? {
    func open(_ value: some Identifiable) -> AnyHashable {
      value.id
    }
    guard let value = value as? any Identifiable else { return nil }
    return open(value)
  }
#else
  // MARK: -
  // MARK: swift(<5.7)

  private enum Witness<T> {}

  // MARK: Equatable

  func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    func open<T>(_: T.Type) -> Bool? {
      (Witness<T>.self as? AnyEquatable.Type)?.isEqual(lhs, rhs)
    }
    return _openExistential(type(of: lhs), do: open)
  }

  private protocol AnyEquatable {
    static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
  }

  extension Witness: AnyEquatable where T: Equatable {
    fileprivate static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
      guard
        let lhs = lhs as? T,
        let rhs = rhs as? T
      else { return false }
      return lhs == rhs
    }
  }

  // MARK: Identifiable

  func _id(_ value: Any) -> AnyHashable? {
    func open<T>(_: T.Type) -> AnyHashable? {
      (Witness<T>.self as? AnyIdentifiable.Type)?.id(value)
    }
    return _openExistential(type(of: value), do: open)
  }

  private protocol AnyIdentifiable {
    static func id(_ value: Any) -> AnyHashable?
  }

  extension Witness: AnyIdentifiable where T: Identifiable {
    fileprivate static func id(_ value: Any) -> AnyHashable? {
      guard let value = value as? T else { return nil }
      return value.id
    }
  }
#endif
