#if swift(>=5.7)
  // MARK: swift(>=5.7)

  // MARK: DependencyKey

  func _liveValue(_ key: Any.Type) -> Any? {
    (key as? any DependencyKey.Type)?.liveValue
  }
#else
  // MARK: -
  // MARK: swift(<5.7)

  private enum Witness<T> {}

  // MARK: DependencyKey

  func _liveValue(_ key: Any.Type) -> Any? {
    func open<T>(_: T.Type) -> Any? {
      (Witness<T>.self as? AnyDependencyKey.Type)?.liveValue
    }
    return _openExistential(key, do: open)
  }

  protocol AnyDependencyKey {
    static var liveValue: Any { get }
  }

  extension Witness: AnyDependencyKey where T: DependencyKey {
    static var liveValue: Any { T.liveValue }
  }
#endif
