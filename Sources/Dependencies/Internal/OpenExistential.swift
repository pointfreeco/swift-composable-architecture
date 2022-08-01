#if swift(>=5.7)
  // MARK: swift(>=5.7)
  // MARK: Equatable

  // MARK: LiveDependencyKey

  func _liveValue(_ key: Any.Type) -> Any? {
    (key as? any LiveDependencyKey.Type)?.liveValue
  }
#else
  // MARK: -
  // MARK: swift(<5.7)

  private enum Witness<T> {}

  // MARK: LiveDependencyKey

  func _liveValue(_ key: Any.Type) -> Any? {
    func open<T>(_: T.Type) -> Any? {
      (Witness<T>.self as? AnyLiveDependencyKey.Type)?.liveValue
    }
    return _openExistential(key, do: open)
  }

  protocol AnyLiveDependencyKey {
    static var liveValue: Any { get }
  }

  extension Witness: AnyLiveDependencyKey where T: LiveDependencyKey {
    static var liveValue: Any { T.liveValue }
  }
#endif
