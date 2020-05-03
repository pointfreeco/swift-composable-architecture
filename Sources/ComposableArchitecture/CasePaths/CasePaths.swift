// NB: This file is vendored from https://github.com/pointfreeco/swift-case-paths to mitigate an SPM bug

extension CasePath where Root == Value {
  /// The identity case path for `Root`: a case path that always successfully extracts a root value.
  public static var `self`: CasePath {
    .init(
      embed: { $0 },
      extract: Optional.some
    )
  }
}

extension CasePath where Root == Void {
  /// Returns a case path that always successfully extracts the given constant value.
  ///
  /// - Parameter value: A constant value.
  /// - Returns: A case path from `()` to `value`.
  public static func constant(_ value: Value) -> CasePath {
    .init(
      embed: { _ in () },
      extract: { .some(value) }
    )
  }
}

extension CasePath where Value == Never {
  /// The never case path for `Root`: a case path that always fails to extract the a value of the uninhabited `Never` type.
  public static var never: CasePath {
    func absurd<A>(_ never: Never) -> A {}
    return .init(
      embed: absurd,
      extract: { _ in nil }
    )
  }
}

extension CasePath where Value: RawRepresentable, Root == Value.RawValue {
  /// Returns a case path for `RawRepresentable` types: a case path that attempts to extract a value that can be represented by a raw value from a raw value.
  public static var rawValue: CasePath {
    .init(
      embed: { $0.rawValue },
      extract: Value.init(rawValue:)
    )
  }
}

extension CasePath where Value: LosslessStringConvertible, Root == String {
  /// Returns a case path for `LosslessStringConvertible` types: a case path that attempts to extract a value that can be represented by a lossless string from a string.
  public static var description: CasePath {
    .init(
      embed: { $0.description },
      extract: Value.init
    )
  }
}
