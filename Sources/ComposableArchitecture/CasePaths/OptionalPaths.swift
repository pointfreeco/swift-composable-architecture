public protocol WritablePath {
  associatedtype Root
  associatedtype Value
  func extract(from root: Root) -> Value?
  func set(into root: inout Root, _ value: Value)
}

extension WritableKeyPath: WritablePath {
  public func extract(from root: Root) -> Value? {
    root[keyPath: self]
  }

  public func set(into root: inout Root, _ value: Value) {
    root[keyPath: self] = value
  }
}

extension CasePath: WritablePath {
  public func set(into root: inout Root, _ value: Value) {
    root = self.embed(value)
  }
}

public struct OptionalPath<Root, Value>: WritablePath {
  private let _extract: (Root) -> Value?
  private let _set: (inout Root, Value) -> Void

  public init(
    extract: @escaping (Root) -> Value?,
    set: @escaping (inout Root, Value) -> Void
  ) {
    self._extract = extract
    self._set = set
  }

  public func extract(from root: Root) -> Value? {
    self._extract(root)
  }

  public func set(into root: inout Root, _ value: Value) {
    self._set(&root, value)
  }

  public init(
    _ keyPath: WritableKeyPath<Root, Value?>
  ) {
    self.init(
      extract: { $0[keyPath: keyPath] },
      set: { $0[keyPath: keyPath] = $1 }
    )
  }

  public init(
    _ casePath: CasePath<Root, Value>
  ) {
    self.init(
      extract: casePath.extract(from:),
      set: { $0 = casePath.embed($1) }
    )
  }

  public func appending<AppendedValue>(
    path: OptionalPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    .init(
      extract: { self.extract(from: $0).flatMap(path.extract(from:)) },
      set: { root, appendedValue in
        guard var value = self.extract(from: root) else { return }
        path.set(into: &value, appendedValue)
        self.set(into: &root, value)
      }
    )
  }

  public func appending<AppendedValue>(
    path: CasePath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    self.appending(path: .init(path))
  }

  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    .init(
      extract: { self.extract(from: $0).map { $0[keyPath: path] } },
      set: { root, appendedValue in
        guard var value = self.extract(from: root) else { return }
        value[keyPath: path] = appendedValue
        self.set(into: &root, value)
      }
    )
  }

  // TODO: Is it safe to keep this overload?
  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue?>
  ) -> OptionalPath<Root, AppendedValue> {

    self.appending(path: .init(path))
  }
}

extension CasePath {
  public func appending<AppendedValue>(
    path: OptionalPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(self).appending(path: path)
  }

  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(self).appending(path: path)
  }

  // TODO: Is it safe to keep this overload?
  public func appending<AppendedValue>(
    path: WritableKeyPath<Value, AppendedValue?>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(self).appending(path: path)
  }
}

extension WritableKeyPath {
  public func appending<AppendedValue>(
    path: OptionalPath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    OptionalPath(
      extract: { path.extract(from: $0[keyPath: self]) },
      set: { root, appendedValue in path.set(into: &root[keyPath: self], appendedValue) }
    )
  }

  public func appending<AppendedValue>(
    path: CasePath<Value, AppendedValue>
  ) -> OptionalPath<Root, AppendedValue> {

    self.appending(path: .init(path))
  }
}

extension OptionalPath where Root == Value {
  public static var `self`: OptionalPath {
    .init(.self)
  }
}

extension OptionalPath where Root == Value? {
  public static var some: OptionalPath {
    .init(/Optional.some)
  }
}
