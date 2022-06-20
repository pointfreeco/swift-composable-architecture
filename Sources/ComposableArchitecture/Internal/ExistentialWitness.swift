#if swift(>=5.7)
  // MARK: - Equatable

  func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    (lhs as? any Equatable)?.isEqual(other: rhs)
  }

  private extension Equatable {
    func isEqual(other: Any) -> Bool {
      self == other as? Self
    }
  }

  // MARK: - LiveDependencyKey

  func _liveValue(_ key: Any.Type) -> Any? {
    (key as? any LiveDependencyKey.Type)?.liveValue
  }
#else
  private enum _Witness<T> {}

  // MARK: - Equatable

  func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    func open<T>(_: T.Type) -> Bool? {
      (_Witness<T>.self as? _AnyEquatable.Type)?.isEqual(lhs, rhs)
    }
    return _openExistential(type(of: lhs), do: open)
  }

  private protocol _AnyEquatable {
    static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
  }

  extension _Witness: _AnyEquatable where T: Equatable {
    fileprivate static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
      guard
        let lhs = lhs as? T,
        let rhs = rhs as? T
      else { return false }
      return lhs == rhs
    }
  }

  // MARK: - LiveDependencyKey

  func _liveValue(_ key: Any.Type) -> Any? {
    func open<T>(_: T.Type) -> Any? {
      (_Witness<T>.self as? _AnyLiveDependencyKey.Type)?.liveValue
    }
    return _openExistential(key, do: open)
  }

  protocol _AnyLiveDependencyKey {
    static var liveValue: Any { get }
  }

  extension _Witness: _AnyLiveDependencyKey where T: LiveDependencyKey {
    static var liveValue: Any { T.liveValue }
  }
#endif
