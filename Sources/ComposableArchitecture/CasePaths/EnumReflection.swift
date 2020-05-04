// NB: This file is vendored from https://github.com/pointfreeco/swift-case-paths to mitigate an SPM bug

import func Foundation.memcmp

extension CasePath {
  /// Returns a case path that extracts values associated with a given enum case initializer.
  ///
  /// - Note: This function is only intended to be used with enum case initializers. Its behavior is otherwise undefined.
  /// - Parameter embed: An enum case initializer.
  /// - Returns: A case path that extracts associated values from enum cases.
  public static func `case`(_ embed: @escaping (Value) -> Root) -> CasePath {
    return self.init(
      embed: embed,
      extract: { ComposableArchitecture.extract(case: embed, from: $0) }
      //      extract: { CasePaths.extract(case: embed, from: $0) }
    )
  }
}

extension CasePath where Value == Void {
  /// Returns a case path that successfully extracts `()` from a given enum case with no associated values.
  ///
  /// - Note: This function is only intended to be used with enum cases that have no associated values. Its behavior is otherwise undefined.
  /// - Parameter value: An enum case with no associated values.
  /// - Returns: A case path that extracts `()` if the case matches, otherwise `nil`.
  public static func `case`(_ value: Root) -> CasePath {
    let label = "\(value)"
    return CasePath(
      embed: { value },
      extract: { "\($0)" == label ? () : nil }
    )
  }
}

/// Attempts to extract values associated with a given enum case initializer from a given root enum.
/// 
///     extract(case: Result<Int, Error>.success, from: .success(42))
///     // 42
///     extract(case: Result<Int, Error>.success, from: .failure(MyError())
///     // nil
///
/// - Note: This function is only intended to be used with enum case initializers. Its behavior is otherwise undefined.
/// - Parameters:
///   - embed: An enum case initializer.
///   - root: A root enum value.
/// - Returns: Values iff they can be extracted from the given enum case initializer and root enum, otherwise `nil`.
public func extract<Root, Value>(case embed: (Value) -> Root, from root: Root) -> Value? {
  func extractHelp(from root: Root) -> ([String?], Value)? {
    if let value = root as? Value {
      var otherRoot = embed(value)
      var root = root
      if memcmp(&root, &otherRoot, MemoryLayout<Root>.size) == 0 {
        return ([], value)
      }
    }
    var path: [String?] = []
    var any: Any = root

    while case let (label?, anyChild)? = Mirror(reflecting: any).children.first {
      path.append(label)
      path.append(String(describing: type(of: anyChild)))
      if let child = anyChild as? Value {
        return (path, child)
      }
      any = anyChild
    }
    if MemoryLayout<Value>.size == 0 {
      return (["\(root)"], unsafeBitCast((), to: Value.self))
    }
    return nil
  }
  if let (rootPath, child) = extractHelp(from: root),
    let (otherPath, _) = extractHelp(from: embed(child)),
    rootPath == otherPath
  { return child }
  return nil
}

/// Returns a function that can attempt to extract associated values from the given enum case initializer.
///
/// Use this function to create new transform functions to pass to higher-order methods like `compactMap`:
///
///     [Result<Int, Error>.success(42), .failure(MyError()]
///       .compactMap(extract(Result.success))
///     // [42]
///
/// - Note: This function is only intended to be used with enum case initializers. Its behavior is otherwise undefined.
/// - Parameter case: An enum case initializer.
/// - Returns: A function that can attempt to extract associated values from an enum.
public func extract<Root, Value>(_ case: @escaping (Value) -> Root) -> (Root) -> (Value?) {
  return { root in
    return extract(case: `case`, from: root)
  }
}
