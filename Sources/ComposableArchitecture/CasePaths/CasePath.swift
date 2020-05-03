// NB: This file is vendored from https://github.com/pointfreeco/swift-case-paths to mitigate an SPM bug

/// A path that supports embedding a value in a root and attempting to extract a root's embedded value.
///
/// This type defines key path-like semantics for enum cases.
public struct CasePath<Root, Value> {
  private let _embed: (Value) -> Root
  private let _extract: (Root) -> Value?

  /// Creates a case path with a pair of functions.
  ///
  /// - Parameters:
  ///   - embed: A function that always succeeds in embedding a value in a root.
  ///   - extract: A function that can optionally fail in extracting a value from a root.
  public init(embed: @escaping (Value) -> Root, extract: @escaping (Root) -> Value?) {
    self._embed = embed
    self._extract = extract
  }

  /// Returns a root by embedding a value.
  ///
  /// - Parameter value: A value to embed.
  /// - Returns: A root that embeds `value`.
  public func embed(_ value: Value) -> Root {
    self._embed(value)
  }

  /// Attempts to extract a value from a root.
  ///
  /// - Parameter root: A root to extract from.
  /// - Returns: A value iff it can be extracted from the given root, otherwise `nil`.
  public func extract(from root: Root) -> Value? {
    self._extract(root)
  }

  /// Returns a new case path created by appending the given case path to this one.
  ///
  /// Use this method to extend this case path to the value type of another case path.
  ///
  /// - Parameter path: The case path to append.
  /// - Returns: A case path from the root of this case path to the value type of `path`.
  public func appending<AppendedValue>(path: CasePath<Value, AppendedValue>) -> CasePath<
    Root, AppendedValue
  > {
    CasePath<Root, AppendedValue>(
      embed: { self.embed(path.embed($0)) },
      extract: { self.extract(from: $0).flatMap(path.extract) }
    )
  }
}
