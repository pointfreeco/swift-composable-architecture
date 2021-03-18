import CasePaths

public struct Lens<Root, Value> {
  public init(
    extract: @escaping (Root) -> Value,
    embed: @escaping (Value, inout Root) -> Void
  ) {
    self._extract = extract
    self._embed = embed
  }
  
  public init(_ keyPath: WritableKeyPath<Root, Value>) {
    self.init(
      extract: { $0[keyPath: keyPath] },
      embed: { $1[keyPath: keyPath] = $0 }
    )
  }
  
  public static func readonly(_ keyPath: KeyPath<Root, Value>) -> Self {
    self.init(
      extract: { $0[keyPath: keyPath] },
      embed: { _, _ in }
    )
  }
  
  private var _extract: (Root) -> Value
  private var _embed: (Value, inout Root) -> Void
  
  public func extract(from root: Root) -> Value { _extract(root) }
  public func embed(_ value: Value, in root: inout Root) { _embed(value, &root) }
  
  public subscript(
    provider: ((inout Root) -> Void) -> Void
  ) -> Value {
    get {
      var root: Root?
      withoutActuallyEscaping(provider) { rootProvider in
        rootProvider { accessor in
          root = accessor
        }
      }
      return extract(from: root!)
    }
    nonmutating set {
      provider({ embed(newValue, in: &$0) })
    }
  }
  
  public subscript(
    read read: () -> Root,
    write write: (Root) -> Void
  ) -> Value {
    get { extract(from: read()) }
    nonmutating set {
      var root = read()
      embed(newValue, in: &root)
      write(root)
    }
  }
}
